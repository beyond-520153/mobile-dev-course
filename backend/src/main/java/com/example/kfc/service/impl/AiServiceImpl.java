package com.example.kfc.service.impl;

import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.config.AiProperties;
import com.example.kfc.domain.dto.AiChatDTO;
import com.example.kfc.domain.dto.AiChatDTO.ChatTurn;
import com.example.kfc.domain.entity.Category;
import com.example.kfc.domain.entity.Product;
import com.example.kfc.domain.vo.AiPickVO;
import com.example.kfc.domain.vo.AiRecommendVO;
import com.example.kfc.domain.vo.AiStoreVO;
import com.example.kfc.domain.vo.ProductVO;
import com.example.kfc.repository.CategoryRepository;
import com.example.kfc.repository.ProductRepository;
import com.example.kfc.service.AiService;
import com.example.kfc.service.BenefitService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * AI 点餐 —— 业务逻辑层实现
 *
 * <p>链路：取真实菜单 → 压成紧凑清单塞进 prompt → 调 qwen（JSON 模式）→
 * 校验模型给的 productId → 对不上就本地补位 → 回填会员价 → 返回。
 *
 * <p>三个刻意的工程取舍：
 * <ol>
 *   <li><b>不让模型生成价格/图片/描述</b>。这些全部回表取，模型只输出 id + 一句理由，
 *       否则必然出现「AI 报 9.9、收银收 21.5」这种没法上线的错；</li>
 *   <li><b>永远有兜底</b>。模型超时、key 失效、id 幻觉，任何一条都会走本地分类轮询补位，
 *       页面不会空着，只是打上 {@code degraded} 标记；</li>
 *   <li><b>失败后冷却 20 秒</b>。否则用户连点「换一换」，每次都要等满读超时。</li>
 * </ol>
 */
@Service
public class AiServiceImpl implements AiService {

    private static final Logger log = LoggerFactory.getLogger(AiServiceImpl.class);

    /** 在售状态 */
    private static final int ON_SHELF = 1;

    /** 默认卡片数 —— 截图是 3×2 六宫格 */
    private static final int DEFAULT_COUNT = 6;

    /** 卡片数上限，再多前端就成九宫格翻页了 */
    private static final int MAX_COUNT = 9;

    /** 塞进 prompt 的菜单文本上限（字符）。菜单再涨也不至于把上下文撑爆 */
    private static final int MAX_MENU_CHARS = 6000;

    /** 用户话术上限 */
    private static final int MAX_MESSAGE_CHARS = 200;

    /** 带进 prompt 的历史条数上限（一问一答算两条） */
    private static final int MAX_HISTORY_TURNS = 6;

    /** 历史单条字数上限：旧话术只是用来「接上下文」，不用原文照搬 */
    private static final int MAX_HISTORY_CHARS = 120;

    /** 模型失败后的冷却时间：这段时间内直接本地推荐，不再去等超时 */
    private static final long FAIL_COOLDOWN_MS = 20_000L;

    /**
     * 系统提示词
     *
     * <p>写法上有几点是踩过坑才加的：
     * 「只输出 JSON」+ {@code response_format=json_object} 双保险；
     * 「reason 不要复述菜名」是因为早期版本 6 条理由全是菜名，等于没写；
     * 明确要求覆盖不同品类，否则模型爱给 6 个汉堡。
     */
    private static final String SYSTEM_PROMPT = """
            你是肯德基 App 里的 AI 点餐助手，名叫「小K」。说话像门店店员：热情、简短、不啰嗦，用中文。

            【任务】
            根据用户这句话，从「今日菜单」里挑出指定数量的餐品，组成一次推荐。

            【规则】
            1. productId 必须原样取自今日菜单，禁止编造、禁止修改数字。
            2. 用户没有明确偏好时，要覆盖不同品类：至少包含 1 个汉堡/主食、1 个套餐或组合、1 个小食、1 个饮品，价格有高有低。
            3. 用户提到口味、预算、人数、品类、忌口（如「辣的」「30 元内」「两个人」「来杯咖啡」「不要饮料」）时，必须严格遵守。
               提到预算时，所选餐品的价格合计不得超过该预算（宁可少选几样贵的，也要守住金额）。
            4. 用户说「换一换」「再来点别的」时，换一组和常规热门不同的组合。
            5. reason 不超过 14 个字，写具体卖点（如「外酥里嫩，两个人的量」），不要复述菜名。
            6. reply 不超过 45 个字，像店员当面说话，不要罗列菜名，不要 markdown、不要表情包。

            【输出格式】只输出一行 JSON，不要代码块、不要解释：
            {"reply":"一句话回复","picks":[{"productId":12,"reason":"推荐理由"}]}
            """;

    private static final String PICKUP_TEXT_PICKUP = "自取";
    private static final String PICKUP_TEXT_DELIVERY = "外送";
    private static final String PICKUP_TEXT_DRIVE = "车速取";

    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final BenefitService benefitService;
    private final AiProperties props;
    private final ObjectMapper objectMapper;
    private final RestTemplate restTemplate;

    /** 冷却截止时间戳（毫秒），0 表示不在冷却期 */
    private volatile long cooldownUntil = 0L;

    public AiServiceImpl(ProductRepository productRepository,
                         CategoryRepository categoryRepository,
                         BenefitService benefitService,
                         AiProperties props,
                         ObjectMapper objectMapper) {
        this.productRepository = productRepository;
        this.categoryRepository = categoryRepository;
        this.benefitService = benefitService;
        this.props = props;
        this.objectMapper = objectMapper;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(props.getConnectTimeoutMs());
        factory.setReadTimeout(props.getReadTimeoutMs());
        this.restTemplate = new RestTemplate(factory);
    }

    /* =============================== 主流程 =============================== */

    @Override
    public AiRecommendVO recommend(AiChatDTO dto) {
        long startedAt = System.currentTimeMillis();
        int count = resolveCount(dto);
        String message = cut(dto == null ? null : dto.getMessage(), MAX_MESSAGE_CHARS);

        List<Product> menu = productRepository.findByStatusOrderBySortOrderAscIdAsc(ON_SHELF);
        if (menu.isEmpty()) {
            throw new BusinessException("菜单里还没有上架餐品，无法推荐");
        }
        Map<Long, String> categoryNames = loadCategoryNames();
        Map<Long, Product> byId = new LinkedHashMap<>();
        for (Product p : menu) {
            byId.put(p.getId(), p);
        }

        AiRecommendVO vo = new AiRecommendVO();
        vo.setStore(buildStore(dto));
        vo.setModel(props.getModel());
        vo.setReply("");
        vo.setDegraded(false);

        /* ---------------- 1. 调模型，拿到「选了哪几个 + 一句回复」 ---------------- */
        // 历史只清洗一次：模型要拿它理解「再加个喝的」，预算约束要拿它接上一轮说的金额
        List<ChatTurn> history = sanitizeHistory(dto);
        Set<Long> modelPicked = new LinkedHashSet<>();
        Map<Long, String> modelReasons = new LinkedHashMap<>();
        if (!props.isEnabled()) {
            markDegraded(vo, "AI 已关闭，这里先展示今日热门");
        } else if (isBlank(props.getApiKey())) {
            markDegraded(vo, "未配置模型 API Key，先展示今日热门");
        } else if (System.currentTimeMillis() < cooldownUntil) {
            markDegraded(vo, "AI 正在恢复中，先展示今日热门");
        } else {
            try {
                String content = callModel(message, history, menu, categoryNames, count);
                ModelPicks parsed = parsePicks(content);
                modelPicked.addAll(parsed.ids);
                modelReasons.putAll(parsed.reasons);
                if (!isBlank(parsed.reply)) {
                    vo.setReply(cut(parsed.reply, 90));
                }
                log.info("AI 推荐成功，模型给了 {} 个 id：{}，耗时 {}ms",
                        parsed.ids.size(), parsed.ids, System.currentTimeMillis() - startedAt);
            } catch (Exception e) {
                // 超时 / 401 / 限流 / 模型乱输出，全部走同一套降级，绝不把异常抛给前端
                markDegraded(vo, shortReason(e));
                cooldownUntil = System.currentTimeMillis() + FAIL_COOLDOWN_MS;
                log.warn("AI 推荐失败，降级为本地推荐：{}", e.getMessage());
            }
        }

        /* ---------------- 2. 校验 id：只认菜单里真实存在且在售的 ---------------- */
        List<Long> finalIds = new ArrayList<>();
        for (Long id : modelPicked) {
            if (finalIds.size() >= count) {
                break;
            }
            Product picked = byId.get(id);
            boolean usable = picked != null
                    && !finalIds.contains(id)
                    && !isCondiment(picked, categoryNames);
            if (usable) {
                finalIds.add(id);
            }
        }
        // 先记下「确实是模型挑的」这一批：预算裁剪后这些 id 的位置会变，
        // 不能再用下标判断来源
        Set<Long> aiIds = new HashSet<>(finalIds);

        // 模型给漏了（或全是幻觉 id）就本地补位，保证卡片数量稳定
        if (finalIds.size() < count) {
            finalIds.addAll(fallbackIds(menu, finalIds, count, categoryNames));
        }

        // 预算硬约束：模型经常「听懂了但没算」，这里在后端兜一道
        String budgetNote = enforceBudget(message, history, finalIds, byId, menu, count, categoryNames);
        if (budgetNote != null) {
            vo.setReply(budgetNote);
        }

        /* ---------------- 3. 回表组装，会员价按当前登录用户现算 ---------------- */
        List<ProductVO> products = new ArrayList<>();
        for (Long id : finalIds) {
            products.add(ProductVO.from(byId.get(id)));
        }
        // 未登录 / 未持卡时这个方法什么都不做，字段保持 null
        benefitService.fillMemberPrice(products);

        List<AiPickVO> items = new ArrayList<>();
        for (int i = 0; i < products.size(); i++) {
            ProductVO product = products.get(i);
            AiPickVO pick = new AiPickVO();
            pick.setIndex(i + 1);
            pick.setLabel("选" + (i + 1));
            pick.setProduct(product);
            // 模型给的理由优先；本地补位的卡片没有理由，用会员价/热销兜一句
            String aiReason = modelReasons.get(product.getId());
            pick.setReason(isBlank(aiReason) ? reasonFor(product) : cut(aiReason, 24));
            pick.setSource(aiIds.contains(product.getId()) ? "AI" : "FALLBACK");
            items.add(pick);
        }
        vo.setItems(items);

        if (isBlank(vo.getReply())) {
            vo.setReply(defaultReply(dto));
        }
        vo.setCostMs(System.currentTimeMillis() - startedAt);
        return vo;
    }

    @Override
    public Map<String, Object> health() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("enabled", props.isEnabled());
        map.put("model", props.getModel());
        map.put("baseUrl", props.getBaseUrl());
        map.put("apiKeyConfigured", !isBlank(props.getApiKey()));
        long left = cooldownUntil - System.currentTimeMillis();
        map.put("cooldownSeconds", left > 0 ? left / 1000 : 0);
        return map;
    }

    /* ============================ 调用模型 ============================ */

    /**
     * 清洗前端带过来的历史
     *
     * <p>三件事必须做，否则这就是一个开放给客户端的 prompt 注入入口：
     * role 只放行 user / assistant（丢掉 system 之类）、单条截断、总量截断。
     * 只留最近 6 条 —— 点餐追问很少超过三轮，更早的既没用又占 token。
     */
    private List<ChatTurn> sanitizeHistory(AiChatDTO dto) {
        List<ChatTurn> raw = dto == null ? null : dto.getHistory();
        if (raw == null || raw.isEmpty()) {
            return List.of();
        }
        List<ChatTurn> kept = new ArrayList<>();
        for (ChatTurn turn : raw) {
            if (turn == null) {
                continue;
            }
            String role = turn.getRole() == null ? "" : turn.getRole().trim();
            if (!"user".equals(role) && !"assistant".equals(role)) {
                continue;
            }
            String text = cut(turn.getText(), MAX_HISTORY_CHARS);
            if (isBlank(text)) {
                continue;
            }
            ChatTurn one = new ChatTurn();
            one.setRole(role);
            one.setText(text);
            kept.add(one);
        }
        if (kept.size() > MAX_HISTORY_TURNS) {
            kept = new ArrayList<>(kept.subList(kept.size() - MAX_HISTORY_TURNS, kept.size()));
        }
        return kept;
    }


    /**
     * 发起一次 chat/completions 调用，返回模型输出的原始文本
     *
     * <p>百炼的兼容模式对 qwen3 系列支持 {@code enable_thinking=false}：
     * 关掉思考链后这类小模型 2~4 秒就能出结果，开着会翻好几倍，点餐场景没必要。
     */
    private String callModel(String message, List<ChatTurn> history, List<Product> menu,
                             Map<Long, String> categoryNames, int count) throws Exception {
        List<Map<String, String>> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", SYSTEM_PROMPT));
        // 历史放在 system 之后、本轮提问之前：模型据此理解「再加个喝的」指的是上一轮
        for (ChatTurn turn : history) {
            messages.add(Map.of("role", turn.getRole(), "content", turn.getText()));
        }
        messages.add(Map.of("role", "user", "content",
                buildUserPrompt(message, menu, categoryNames, count)));

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", props.getModel());
        body.put("messages", messages);
        body.put("temperature", props.getTemperature());
        body.put("max_tokens", props.getMaxTokens());
        body.put("enable_thinking", false);
        body.put("response_format", Map.of("type", "json_object"));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(props.getApiKey());

        String raw = restTemplate.postForObject(
                endpoint(), new HttpEntity<>(body, headers), String.class);
        if (isBlank(raw)) {
            throw new IllegalStateException("模型返回空响应体");
        }

        JsonNode root = objectMapper.readTree(raw);
        JsonNode choices = root.path("choices");
        if (!choices.isArray() || choices.isEmpty()) {
            throw new IllegalStateException("模型返回里没有 choices：" + cut(raw, 120));
        }
        return choices.get(0).path("message").path("content").asText("");
    }

    /** baseUrl 允许配成带尾斜杠的形式，这里统一收口 */
    private String endpoint() {
        String base = props.getBaseUrl() == null ? "" : props.getBaseUrl().trim();
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }
        return base + "/chat/completions";
    }

    /**
     * 拼用户消息：一句偏好 + 一份紧凑菜单
     *
     * <p>菜单格式 {@code 分类: id 名称 ¥价格; ...}，是 token 与可读性之间折中的写法 ——
     * 96 个餐品大约 1.2k token，比 JSON 数组省一半，模型也不会因为字段太多而看串行。
     */
    private String buildUserPrompt(String message, List<Product> menu,
                                   Map<Long, String> categoryNames, int count) {
        StringBuilder sb = new StringBuilder();
        sb.append("用户说：").append(isBlank(message) ? "（刚进店，还没说话）" : message).append('\n');
        sb.append("需要推荐 ").append(count).append(" 个餐品。\n\n【今日菜单】\n");

        Map<String, List<Product>> byCategory = new LinkedHashMap<>();
        for (Product p : menu) {
            String cat = categoryNames.getOrDefault(p.getCategoryId(), "其他");
            byCategory.computeIfAbsent(cat, k -> new ArrayList<>()).add(p);
        }

        for (Map.Entry<String, List<Product>> entry : byCategory.entrySet()) {
            sb.append(entry.getKey()).append(": ");
            List<String> cells = new ArrayList<>();
            for (Product p : entry.getValue()) {
                if (p.getStock() != null && p.getStock() <= 0) {
                    continue;
                }
                cells.add(p.getId() + " " + p.getName() + " ¥" + plain(p.getPrice()));
            }
            sb.append(String.join("; ", cells)).append('\n');
            if (sb.length() > MAX_MENU_CHARS) {
                sb.append("（菜单过长，已截断）\n");
                break;
            }
        }
        return sb.toString();
    }

    /* ============================ 解析模型输出 ============================ */

    /** 模型输出：一句回复 + 若干 productId */
    private static class ModelPicks {
        String reply = "";
        List<Long> ids = new ArrayList<>();
        Map<Long, String> reasons = new LinkedHashMap<>();
    }

    /**
     * 解析模型给的 JSON
     *
     * <p>即使开了 {@code response_format=json_object}，也有概率被包上 ```json 围栏
     * 或在前后加一句「好的，这是推荐」。所以这里先剥围栏、再截首尾花括号，最后才 parse。
     */
    private ModelPicks parsePicks(String content) throws Exception {
        ModelPicks result = new ModelPicks();
        String json = extractJson(content);
        if (json == null) {
            throw new IllegalStateException("模型没有输出 JSON：" + cut(content, 120));
        }

        JsonNode root = objectMapper.readTree(json);
        // 容忍模型把整个对象包成 {"result": {...}}
        if (!root.has("picks") && root.has("result")) {
            root = root.path("result");
        }
        result.reply = root.path("reply").asText("");

        JsonNode picks = root.path("picks");
        if (picks.isArray()) {
            for (JsonNode node : picks) {
                long id = node.isNumber() ? node.asLong() : node.path("productId").asLong(0);
                if (id > 0) {
                    result.ids.add(id);
                    String reason = node.path("reason").asText("");
                    if (!isBlank(reason)) {
                        result.reasons.put(id, reason.trim());
                    }
                }
            }
        }
        if (result.ids.isEmpty()) {
            throw new IllegalStateException("模型没有给出可用的 productId");
        }
        return result;
    }

    /** 从可能带围栏/带前后缀的文本里抠出 JSON 对象 */
    private String extractJson(String content) {
        if (isBlank(content)) {
            return null;
        }
        String text = content.trim();

        int fence = text.indexOf("```");
        if (fence >= 0) {
            int start = text.indexOf('\n', fence);
            int end = text.lastIndexOf("```");
            if (start > 0 && end > start) {
                text = text.substring(start + 1, end).trim();
            }
        }

        int first = text.indexOf('{');
        int last = text.lastIndexOf('}');
        if (first < 0 || last <= first) {
            return null;
        }
        return text.substring(first, last + 1);
    }

    /* ============================ 本地兜底 ============================ */

    /**
     * 本地补位：按分类轮询挑，避免补出来 6 个全是同一种
     *
     * <p>组内排序：有库存 → 有图 → 原有 sortOrder。有图的排前面是因为
     * 六宫格里出现一张灰底占位图会很难看。
     */
    private List<Long> fallbackIds(List<Product> menu, List<Long> exclude, int count,
                                   Map<Long, String> categoryNames) {
        Map<Long, List<Product>> byCategory = new LinkedHashMap<>();
        for (Product p : menu) {
            if (exclude.contains(p.getId()) || isCondiment(p, categoryNames)) {
                continue;
            }
            byCategory.computeIfAbsent(p.getCategoryId(), k -> new ArrayList<>()).add(p);
        }
        for (List<Product> group : byCategory.values()) {
            group.sort((a, b) -> {
                int sa = a.getStock() != null && a.getStock() > 0 ? 0 : 1;
                int sb = b.getStock() != null && b.getStock() > 0 ? 0 : 1;
                if (sa != sb) {
                    return sa - sb;
                }
                boolean ia = !isBlank(a.getImage());
                boolean ib = !isBlank(b.getImage());
                if (ia != ib) {
                    return ia ? -1 : 1;
                }
                int sortA = a.getSortOrder() == null ? 0 : a.getSortOrder();
                int sortB = b.getSortOrder() == null ? 0 : b.getSortOrder();
                return sortA - sortB;
            });
        }

        List<Long> result = new ArrayList<>();
        int round = 0;
        while (result.size() + exclude.size() < count && round < 30) {
            boolean added = false;
            for (List<Product> group : byCategory.values()) {
                if (round < group.size()) {
                    Long id = group.get(round).getId();
                    if (!result.contains(id)) {
                        result.add(id);
                        added = true;
                        if (result.size() + exclude.size() >= count) {
                            break;
                        }
                    }
                }
            }
            if (!added) {
                break;
            }
            round++;
        }
        return result;
    }

    /** 兜底卡片没有模型理由，用一句中性描述填上，前端可显示可不显示 */
    /* ------------------------------ 预算硬约束 ------------------------------ */

    /** 「21 元」「9.9 块」这种带单位的金额 */
    private static final Pattern BUDGET_UNIT =
            Pattern.compile("([0-9]{1,4}(?:[.][0-9]+)?)[ ]*(?:元|块钱|块)");
    /** 「60 以内」「50 以下」 */
    private static final Pattern BUDGET_WITHIN =
            Pattern.compile("([0-9]{1,4}(?:[.][0-9]+)?)[ ]*(?:以内|以下|之内)");
    /** 「预算 50」「不超过 40」「控制在 30」 */
    private static final Pattern BUDGET_LEAD =
            Pattern.compile("(?:预算|不超过|最多|控制在|低于|别超)[ ]*([0-9]{1,4}(?:[.][0-9]+)?)");

    /**
     * 把推荐结果压进用户给的预算里
     *
     * <p>prompt 里已经写了「合计不得超过预算」，但模型经常听懂了却没算——
     * 尤其在「两个人吃 60 以内」这种既要数量又要金额的句子里，它更愿意凑满 6 样。
     * 所以这里在后端兜一道硬约束：
     * <ol>
     *   <li>先按模型的选择算总额，没超就原样返回；</li>
     *   <li>超了就从<strong>最贵的</strong>往下砍——砍一件贵的顶砍两三件便宜的，样数损失最小；</li>
     *   <li>砍完再拿菜单里<strong>最便宜</strong>的补位，只要能塞进预算就塞，塞不下就少给一张卡。</li>
     * </ol>
     * 宁可少推荐一样，也不推荐一个用户明确说了买不起的组合。
     *
     * @return 触发裁剪时返回改写后的回复文案；没超预算返回 null（保留模型自己那句话）
     */
    private String enforceBudget(String message, List<ChatTurn> history, List<Long> ids,
                                 Map<Long, Product> byId, List<Product> menu, int count,
                                 Map<Long, String> categoryNames) {
        BigDecimal budget = resolveBudget(message, history);
        if (budget == null || budget.signum() <= 0) {
            return null;
        }
        BigDecimal total = sumPrice(ids, byId);
        if (total.compareTo(budget) <= 0) {
            return null;
        }

        List<Long> kept = new ArrayList<>(ids);
        while (total.compareTo(budget) > 0 && !kept.isEmpty()) {
            Long priciest = null;
            BigDecimal max = null;
            for (Long id : kept) {
                BigDecimal price = priceOf(byId.get(id));
                if (max == null || price.compareTo(max) > 0) {
                    max = price;
                    priciest = id;
                }
            }
            kept.remove(priciest);
            total = total.subtract(max);
        }

        List<Product> cheapFirst = new ArrayList<>(menu);
        cheapFirst.sort((a, b) -> priceOf(a).compareTo(priceOf(b)));
        for (Product candidate : cheapFirst) {
            if (kept.size() >= count) {
                break;
            }
            if (kept.contains(candidate.getId()) || isCondiment(candidate, categoryNames)) {
                continue;
            }
            BigDecimal price = priceOf(candidate);
            if (total.add(price).compareTo(budget) <= 0) {
                kept.add(candidate.getId());
                total = total.add(price);
            }
        }

        ids.clear();
        ids.addAll(kept);
        log.info("预算 {} 元触发裁剪，最终 {} 样、合计 {} 元", plain(budget), kept.size(), plain(total));
        return "按您 " + plain(budget) + " 元以内的预算，这几样合计 ¥" + plain(total) + "，不会超。";
    }

    /** 用户主动撤销预算约束的措辞 */
    private static final String[] BUDGET_CANCEL = {
            "不限预算", "预算不限", "不用管预算", "别管预算", "不管预算", "随便花"
    };

    /**
     * 本轮该守多少预算
     *
     * <p>多轮对话里用户通常只说一次预算：「两个人吃 60 以内」→「再加个喝的」。
     * 第二轮句子本身没有金额，但约束还在，所以当前句抠不到就往前翻用户说过的话，
     * 命中最近一次提到的金额。<b>顺序是从近到远</b>，因为用户可能改口「改成 40」。
     * 说「不限预算」这类话则视为撤销，不再继承。
     */
    private BigDecimal resolveBudget(String message, List<ChatTurn> history) {
        for (String cancel : BUDGET_CANCEL) {
            if (message != null && message.contains(cancel)) {
                return null;
            }
        }
        BigDecimal own = parseBudget(message);
        if (own != null) {
            return own;
        }
        if (history == null) {
            return null;
        }
        for (int i = history.size() - 1; i >= 0; i--) {
            ChatTurn turn = history.get(i);
            if (turn == null || !"user".equals(turn.getRole())) {
                continue;
            }
            BigDecimal older = parseBudget(turn.getText());
            if (older != null) {
                log.info("本轮没提金额，沿用上一轮预算 {} 元", plain(older));
                return older;
            }
        }
        return null;
    }

    /** 抠预算金额；一句话里多个数字时取第一个「像预算」的 */
    private BigDecimal parseBudget(String message) {
        if (isBlank(message)) {
            return null;
        }
        for (Pattern pattern : new Pattern[]{BUDGET_WITHIN, BUDGET_LEAD, BUDGET_UNIT}) {
            Matcher matcher = pattern.matcher(message);
            if (matcher.find()) {
                try {
                    BigDecimal value = new BigDecimal(matcher.group(1));
                    // 1 元以下的「预算」基本是「1 个人」被误读，直接忽略
                    if (value.compareTo(BigDecimal.ONE) > 0) {
                        return value;
                    }
                } catch (NumberFormatException ignored) {
                    // 正则已经限制了数字形态，这里只是防御
                }
            }
        }
        return null;
    }

    private BigDecimal sumPrice(List<Long> ids, Map<Long, Product> byId) {
        BigDecimal total = BigDecimal.ZERO;
        for (Long id : ids) {
            total = total.add(priceOf(byId.get(id)));
        }
        return total;
    }

    private static BigDecimal priceOf(Product product) {
        return product == null || product.getPrice() == null ? BigDecimal.ZERO : product.getPrice();
    }

    /**
     * 酱料、撒粉、料包这类「凑单件」
     *
     * <p>补位是「最便宜的往上填」，如果不拦，菜单里 0.9 元的撒粉和 1.2 元的蘸酱
     * 一定会被选中——预算看着达标了，但用户拿到的是「六样里有三样是调料」。
     * 宁可少给一张卡，也不塞这种东西。
     */
    private static boolean isCondiment(Product product, Map<Long, String> categoryNames) {
        if (product == null) {
            return true;
        }
        String name = product.getName() == null ? "" : product.getName();
        for (String word : new String[]{"酱", "料包", "风味粉", "撒粉", "蘸", "调味", "加料", "袋", "包装", "周边", "玩具"}) {
            if (name.contains(word)) {
                return true;
            }
        }
        String category = categoryNames.get(product.getCategoryId());
        return category != null && (category.contains("加料") || category.contains("酱"));
    }

    private String reasonFor(ProductVO product) {
        if (product.getStock() != null && product.getStock() <= 0) {
            return "今日已售罄";
        }
        if (product.getMemberPrice() != null && product.getMemberPriceText() != null) {
            return product.getMemberPriceText();
        }
        return "门店热销款";
    }

    private String defaultReply(AiChatDTO dto) {
        String pickup = pickupText(dto == null ? null : dto.getPickupType());
        return "今天这几样最受欢迎，" + pickup + "下单最快 15 分钟就能取，选一个试试？";
    }

    /* ============================ 小工具 ============================ */

    private int resolveCount(AiChatDTO dto) {
        if (dto == null || dto.getCount() == null) {
            return DEFAULT_COUNT;
        }
        int count = dto.getCount();
        if (count < 1) {
            return DEFAULT_COUNT;
        }
        return Math.min(count, MAX_COUNT);
    }

    private Map<Long, String> loadCategoryNames() {
        Map<Long, String> map = new LinkedHashMap<>();
        for (Category c : categoryRepository.findAllByOrderBySortOrderAscIdAsc()) {
            map.put(c.getId(), c.getName());
        }
        return map;
    }

    private AiStoreVO buildStore(AiChatDTO dto) {
        String type = dto == null || isBlank(dto.getPickupType()) ? "PICKUP" : dto.getPickupType().trim();
        AiStoreVO store = new AiStoreVO();
        store.setName(props.getStoreName());
        store.setAddress(props.getStoreAddress());
        store.setDistance(props.getStoreDistance());
        store.setPickupType(type);
        store.setPickupText(pickupText(type));
        return store;
    }

    private String pickupText(String type) {
        if (type == null) {
            return PICKUP_TEXT_PICKUP;
        }
        return switch (type.toUpperCase()) {
            case "DELIVERY" -> PICKUP_TEXT_DELIVERY;
            case "DRIVE" -> PICKUP_TEXT_DRIVE;
            default -> PICKUP_TEXT_PICKUP;
        };
    }

    private void markDegraded(AiRecommendVO vo, String reason) {
        vo.setDegraded(true);
        vo.setDegradeReason(reason);
    }

    /** 降级原因要能给人看，不能把整段堆栈塞进 JSON */
    private String shortReason(Exception e) {
        String msg = e.getMessage();
        if (isBlank(msg)) {
            return "AI 暂时无法连接，先看看今日热门";
        }
        if (msg.contains("timed out") || msg.contains("Timeout")) {
            return "AI 响应超时，先看看今日热门";
        }
        if (msg.contains("401") || msg.contains("Unauthorized")) {
            return "模型鉴权失败，请检查 API Key";
        }
        if (msg.contains("429")) {
            return "AI 请求过于频繁，稍后再试";
        }
        return "AI 暂时不可用，先看看今日热门";
    }

    private String plain(BigDecimal value) {
        if (value == null) {
            return "0";
        }
        return value.stripTrailingZeros().toPlainString();
    }

    private static boolean isBlank(String s) {
        return s == null || s.trim().isEmpty();
    }

    private static String cut(String s, int max) {
        if (s == null) {
            return "";
        }
        String t = s.trim();
        return t.length() <= max ? t : t.substring(0, max);
    }
}
