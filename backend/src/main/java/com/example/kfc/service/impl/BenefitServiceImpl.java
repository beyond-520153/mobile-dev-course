package com.example.kfc.service.impl;

import com.example.kfc.domain.entity.BenefitRule;
import com.example.kfc.domain.entity.BenefitUsage;
import com.example.kfc.domain.entity.Category;
import com.example.kfc.domain.entity.MemberCard;
import com.example.kfc.domain.vo.CartItemVO;
import com.example.kfc.domain.vo.DiscountLineVO;
import com.example.kfc.domain.vo.MemberCardVO;
import com.example.kfc.domain.vo.OrderQuoteVO;
import com.example.kfc.domain.vo.UserBenefitVO;
import com.example.kfc.repository.BenefitRuleRepository;
import com.example.kfc.repository.BenefitUsageRepository;
import com.example.kfc.repository.CategoryRepository;
import com.example.kfc.repository.MemberCardRepository;
import com.example.kfc.service.BenefitService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 会员卡权益 —— 业务逻辑层实现（折扣计算引擎）
 *
 * <p>算法是「按件」算的，不是按订单总额打折：
 * 把购物车展开成一件件单价（Unit），每条规则只认自己适用分类里、还没被别的规则
 * 用掉的那些件，按下单顺序取最划算的组合（折扣/立减取最便宜的，特价取最贵的），
 * 命中后把这些件标记为已用，所以同一杯咖啡不会被「大神卡 10 元」和
 * 「咖啡卡立减 8 元」重复抵扣。
 *
 * <p>不参与计算的规则一定不写流水，参与的一定写一条，保证「每日 N 次」可核对。
 */
@Service
public class BenefitServiceImpl implements BenefitService {

    private static final Logger log = LoggerFactory.getLogger(BenefitServiceImpl.class);

    private static final String PICKUP = "PICKUP";
    private static final String DELIVERY = "DELIVERY";
    private static final String CARD_GOD = "GOD";

    private static final String TYPE_PERCENT_OFF = "PERCENT_OFF";
    private static final String TYPE_AMOUNT_OFF = "AMOUNT_OFF";
    private static final String TYPE_FIXED_PRICE = "FIXED_PRICE";
    private static final String TYPE_FREE_DELIVERY = "FREE_DELIVERY";

    /** 外送费标准价：官方渠道 9 元；大神卡满 29 元可免 */
    private static final BigDecimal DELIVERY_FEE = new BigDecimal("9.00");

    private final BenefitRuleRepository ruleRepository;
    private final BenefitUsageRepository usageRepository;
    private final MemberCardRepository cardRepository;
    private final CategoryRepository categoryRepository;

    public BenefitServiceImpl(BenefitRuleRepository ruleRepository,
                              BenefitUsageRepository usageRepository,
                              MemberCardRepository cardRepository,
                              CategoryRepository categoryRepository) {
        this.ruleRepository = ruleRepository;
        this.usageRepository = usageRepository;
        this.cardRepository = cardRepository;
        this.categoryRepository = categoryRepository;
    }

    /* ============================== 对外能力 ============================== */

    @Override
    public OrderQuoteVO quote(Long userId, String pickupType, List<CartItemVO> items) {
        String pickup = normalizePickup(pickupType);
        List<CartItemVO> cart = items == null ? List.of() : items;

        BigDecimal goods = cart.stream()
                .map(CartItemVO::getSubtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal deliveryFee = DELIVERY.equals(pickup) && !cart.isEmpty()
                ? DELIVERY_FEE : BigDecimal.ZERO;

        OrderQuoteVO vo = new OrderQuoteVO();
        vo.setUserId(userId);
        vo.setPickupType(pickup);
        vo.setPickupTypeText(DELIVERY.equals(pickup) ? "外送" : "到店自取");
        vo.setItems(new ArrayList<>(cart));
        vo.setItemCount(cart.stream().mapToInt(CartItemVO::getQuantity).sum());
        vo.setGoodsAmount(scale(goods));
        vo.setDeliveryFee(scale(deliveryFee));
        vo.setDiscounts(new ArrayList<>());

        if (cart.isEmpty()) {
            return finish(vo, goods, deliveryFee, BigDecimal.ZERO, "购物车是空的，先去点餐吧");
        }

        List<MemberCard> cards = userId == null ? List.of() : activeCards(userId);
        Set<String> cardTypes = cards.stream().map(MemberCard::getCardType).collect(Collectors.toSet());
        MemberCard god = cards.stream()
                .filter(c -> CARD_GOD.equals(c.getCardType()))
                .findFirst().orElse(null);
        vo.setGodCard(god != null);
        vo.setGodCardName(god == null ? null : god.getCardName());

        if (cardTypes.isEmpty()) {
            return finish(vo, goods, deliveryFee, BigDecimal.ZERO,
                    "开通大神卡：咖啡 10 元、外送免配送费、人气套餐立减 5 元");
        }

        List<BenefitRule> rules = ruleRepository
                .findByCardTypeInAndStatusOrderBySortOrderAsc(cardTypes, 1);
        Map<String, Integer> usedToday = todayUsage(userId, LocalDate.now());
        LocalTime now = LocalTime.now();
        List<Unit> units = expand(cart);

        BigDecimal goodsDiscount = BigDecimal.ZERO;
        BigDecimal deliveryDiscount = BigDecimal.ZERO;
        List<DiscountLineVO> lines = new ArrayList<>();

        for (BenefitRule rule : rules) {
            if (!pickupAllowed(rule, pickup)) {
                continue;
            }
            if (!inTimeWindow(rule, now)) {
                continue;
            }
            int limit = rule.getDailyLimit() == null ? 1 : rule.getDailyLimit();
            if (usedToday.getOrDefault(rule.getCode(), 0) >= limit) {
                continue;
            }
            BigDecimal threshold = rule.getThresholdAmount() == null
                    ? BigDecimal.ZERO : rule.getThresholdAmount();
            if (goods.compareTo(threshold) < 0) {
                continue;
            }

            // ---- 免配送费：不动商品金额，抵的是外送费 ----
            if (TYPE_FREE_DELIVERY.equals(rule.getBenefitType())) {
                if (deliveryFee.signum() <= 0) {
                    continue;
                }
                DiscountLineVO line = baseLine(rule);
                line.setDiscountAmount(scale(deliveryFee));
                line.setItemText("外送费 ¥" + scale(deliveryFee));
                line.setOnDeliveryFee(true);
                lines.add(line);
                deliveryDiscount = deliveryDiscount.add(deliveryFee);
                continue;
            }

            // ---- 商品类优惠：只在适用分类里挑还没被用掉的件 ----
            List<Unit> eligible = units.stream()
                    .filter(u -> !u.used && inScope(rule, u))
                    .collect(Collectors.toList());
            int need = Math.max(1, rule.getMinQuantity() == null ? 1 : rule.getMinQuantity());
            if (eligible.size() < need) {
                continue;
            }

            List<Unit> picked;
            BigDecimal discount;
            switch (rule.getBenefitType()) {
                case TYPE_FIXED_PRICE -> {
                    // 特价：只对原价高于特价的餐品生效，从最贵的开始挑
                    BigDecimal fixed = rule.getDiscountValue();
                    picked = eligible.stream()
                            .filter(u -> u.price.compareTo(fixed) > 0)
                            .sorted(Comparator.comparing((Unit u) -> u.price).reversed())
                            .limit(need)
                            .collect(Collectors.toList());
                    if (picked.size() < need) {
                        continue;
                    }
                    discount = picked.stream()
                            .map(u -> u.price.subtract(fixed))
                            .reduce(BigDecimal.ZERO, BigDecimal::add);
                }
                case TYPE_AMOUNT_OFF -> {
                    picked = cheapest(eligible, need);
                    discount = rule.getDiscountValue().min(sumPrice(picked));
                }
                default -> {
                    // 折扣：rate = 0.60 表示付 6 折，优惠 = 基价 × (1 - 0.60)
                    picked = cheapest(eligible, need);
                    BigDecimal base = sumPrice(picked);
                    discount = base.multiply(BigDecimal.ONE.subtract(rule.getDiscountValue()));
                    if (rule.getMaxDiscount() != null
                            && discount.compareTo(rule.getMaxDiscount()) > 0) {
                        discount = rule.getMaxDiscount();
                    }
                }
            }

            discount = scale(discount);
            if (discount.signum() <= 0) {
                continue;
            }
            // 商品金额不能被减成负数
            BigDecimal remain = goods.subtract(goodsDiscount);
            if (discount.compareTo(remain) > 0) {
                discount = remain;
            }
            if (discount.signum() <= 0) {
                continue;
            }

            picked.forEach(u -> u.used = true);
            DiscountLineVO line = baseLine(rule);
            line.setDiscountAmount(scale(discount));
            line.setItemText(itemText(picked));
            line.setOnDeliveryFee(false);
            lines.add(line);
            goodsDiscount = goodsDiscount.add(discount);
        }

        if (lines.isEmpty()) {
            return finish(vo, goods, deliveryFee, BigDecimal.ZERO,
                    hintWhenNothingApplied(rules, pickup, goods, now, usedToday));
        }
        vo.setDiscounts(lines);
        return finish(vo, goods, deliveryFee, goodsDiscount.add(deliveryDiscount), null);
    }

    @Override
    @Transactional
    public List<String> consume(Long userId, OrderQuoteVO quote) {
        if (userId == null || quote == null
                || quote.getDiscounts() == null || quote.getDiscounts().isEmpty()) {
            return List.of();
        }
        LocalDate today = LocalDate.now();
        List<String> codes = new ArrayList<>(quote.getDiscounts().size());
        for (DiscountLineVO line : quote.getDiscounts()) {
            BenefitUsage usage = usageRepository
                    .findByUserIdAndRuleCodeAndUseDate(userId, line.getCode(), today)
                    .orElseGet(() -> {
                        BenefitUsage created = new BenefitUsage();
                        created.setUserId(userId);
                        created.setRuleCode(line.getCode());
                        created.setUseDate(today);
                        created.setUsedCount(0);
                        return created;
                    });
            usage.setUsedCount(usage.getUsedCount() + 1);
            usageRepository.save(usage);
            codes.add(line.getCode());
        }
        log.info("权益扣次：userId={}，规则={}，日期={}", userId, codes, today);
        return codes;
    }

    @Override
    @Transactional
    public void release(Long userId, String benefitCodes, LocalDate useDate) {
        if (userId == null || benefitCodes == null || benefitCodes.isBlank()) {
            return;
        }
        LocalDate date = useDate == null ? LocalDate.now() : useDate;
        for (String code : benefitCodes.split(",")) {
            String trimmed = code.trim();
            if (trimmed.isEmpty()) {
                continue;
            }
            usageRepository.findByUserIdAndRuleCodeAndUseDate(userId, trimmed, date)
                    .ifPresent(usage -> {
                        int next = Math.max(0, usage.getUsedCount() - 1);
                        usage.setUsedCount(next);
                        usageRepository.save(usage);
                    });
        }
        log.info("权益归还：userId={}，规则={}，日期={}", userId, benefitCodes, date);
    }

    @Override
    public List<UserBenefitVO> listBenefits(Long userId) {
        if (userId == null) {
            return List.of();
        }
        List<MemberCard> cards = activeCards(userId);
        Set<String> cardTypes = cards.stream().map(MemberCard::getCardType).collect(Collectors.toSet());
        if (cardTypes.isEmpty()) {
            return List.of();
        }
        Map<Long, String> categoryNames = categoryNames();
        Map<String, Integer> usedToday = todayUsage(userId, LocalDate.now());
        LocalTime now = LocalTime.now();

        List<UserBenefitVO> result = new ArrayList<>();
        for (BenefitRule rule : ruleRepository.findByCardTypeInAndStatusOrderBySortOrderAsc(cardTypes, 1)) {
            int limit = rule.getDailyLimit() == null ? 1 : rule.getDailyLimit();
            int used = usedToday.getOrDefault(rule.getCode(), 0);
            int remaining = Math.max(0, limit - used);
            boolean activeNow = inTimeWindow(rule, now);
            boolean usable = activeNow && remaining > 0;

            UserBenefitVO vo = new UserBenefitVO();
            vo.setCode(rule.getCode());
            vo.setCardType(rule.getCardType());
            vo.setName(rule.getName());
            vo.setBenefitType(rule.getBenefitType());
            vo.setDescription(rule.getDescription());
            vo.setValueText(valueText(rule));
            vo.setScopeText(scopeText(rule, categoryNames));
            vo.setTimeText(timeText(rule));
            vo.setDailyLimit(limit);
            vo.setUsedToday(used);
            vo.setRemaining(remaining);
            vo.setActiveNow(activeNow);
            vo.setUsable(usable);
            if (!activeNow) {
                vo.setUnavailableReason("不在可用时段（" + timeText(rule) + "）");
            } else if (remaining <= 0) {
                vo.setUnavailableReason("今日次数已用完，明天再来");
            }
            result.add(vo);
        }
        return result;
    }

    @Override
    public MemberCardVO activeGodCard(Long userId) {
        if (userId == null) {
            return null;
        }
        return activeCards(userId).stream()
                .filter(c -> CARD_GOD.equals(c.getCardType()))
                .findFirst()
                .map(MemberCardVO::from)
                .orElse(null);
    }

    @Override
    public boolean isGodCardOwner(Long userId) {
        return activeGodCard(userId) != null;
    }

    /* ============================== 内部实现 ============================== */

    /** 收尾：算应付金额、汇总文案 */
    private OrderQuoteVO finish(OrderQuoteVO vo, BigDecimal goods, BigDecimal deliveryFee,
                                BigDecimal discount, String hint) {
        BigDecimal total = scale(discount);
        vo.setDiscountAmount(total);
        vo.setPayAmount(scale(goods.add(deliveryFee).subtract(total)));
        if (total.signum() > 0) {
            String card = Boolean.TRUE.equals(vo.getGodCard()) && vo.getGodCardName() != null
                    ? "大神卡 " + vo.getGodCardName() : "会员卡";
            vo.setBenefitText(card + "已省 ¥" + total.toPlainString());
        }
        vo.setHint(hint);
        return vo;
    }

    /** 生效中的卡（顺手把过期的标成 EXPIRED，和会员服务口径一致） */
    private List<MemberCard> activeCards(Long userId) {
        List<MemberCard> cards = cardRepository
                .findByUserIdAndStatusOrderByExpireAtDesc(userId, "ACTIVE");
        OffsetDateTime now = OffsetDateTime.now();
        List<MemberCard> result = new ArrayList<>(cards.size());
        for (MemberCard card : cards) {
            if (card.getExpireAt() != null && card.getExpireAt().isBefore(now)) {
                card.setStatus("EXPIRED");
                cardRepository.save(card);
                continue;
            }
            result.add(card);
        }
        return result;
    }

    /** 当日各规则已用次数 */
    private Map<String, Integer> todayUsage(Long userId, LocalDate date) {
        if (userId == null) {
            return Map.of();
        }
        Map<String, Integer> map = new HashMap<>();
        for (BenefitUsage usage : usageRepository.findByUserIdAndUseDate(userId, date)) {
            map.put(usage.getRuleCode(), usage.getUsedCount());
        }
        return map;
    }

    /** 把购物车展开成一件件单价，折扣按件算 */
    private List<Unit> expand(List<CartItemVO> cart) {
        List<Unit> units = new ArrayList<>();
        for (CartItemVO item : cart) {
            int qty = item.getQuantity() == null ? 0 : item.getQuantity();
            for (int i = 0; i < qty; i++) {
                units.add(new Unit(item.getProductId(), item.getProductName(),
                        item.getCategoryId(), item.getPrice()));
            }
        }
        return units;
    }

    private boolean inScope(BenefitRule rule, Unit unit) {
        if ("ALL".equalsIgnoreCase(rule.getScopeType())) {
            return true;
        }
        if (rule.getScopeIds() == null || rule.getScopeIds().isBlank() || unit.categoryId == null) {
            return false;
        }
        return Arrays.stream(rule.getScopeIds().split(","))
                .map(String::trim)
                .anyMatch(id -> id.equals(String.valueOf(unit.categoryId)));
    }

    private boolean pickupAllowed(BenefitRule rule, String pickup) {
        if (rule.getPickupTypes() == null || rule.getPickupTypes().isBlank()) {
            return true;
        }
        return Arrays.stream(rule.getPickupTypes().split(","))
                .map(String::trim)
                .anyMatch(type -> type.equalsIgnoreCase(pickup));
    }

    /** 时段判定；首尾都不配表示全天 */
    private boolean inTimeWindow(BenefitRule rule, LocalTime now) {
        if (rule.getStartTime() == null || rule.getEndTime() == null) {
            return true;
        }
        return !now.isBefore(rule.getStartTime()) && !now.isAfter(rule.getEndTime());
    }

    private List<Unit> cheapest(List<Unit> units, int need) {
        return units.stream()
                .sorted(Comparator.comparing((Unit u) -> u.price))
                .limit(need)
                .collect(Collectors.toList());
    }

    private BigDecimal sumPrice(List<Unit> units) {
        return units.stream().map(u -> u.price).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private DiscountLineVO baseLine(BenefitRule rule) {
        DiscountLineVO line = new DiscountLineVO();
        line.setCode(rule.getCode());
        line.setName(rule.getName());
        line.setBenefitType(rule.getBenefitType());
        line.setDescription(rule.getDescription());
        return line;
    }

    /** 命中餐品文案，如「拿铁 ×1、红豆派 ×1」 */
    private String itemText(List<Unit> picked) {
        Map<String, Long> grouped = picked.stream().collect(Collectors.groupingBy(
                u -> u.productName == null ? "餐品" : u.productName,
                LinkedHashMap::new,
                Collectors.counting()));
        return grouped.entrySet().stream()
                .map(e -> e.getKey() + " ×" + e.getValue())
                .collect(Collectors.joining("、"));
    }

    private String hintWhenNothingApplied(List<BenefitRule> rules, String pickup,
                                          BigDecimal goods, LocalTime now,
                                          Map<String, Integer> usedToday) {
        boolean anyInWindow = false;
        boolean anyQuota = false;
        boolean anyThreshold = false;
        boolean anyScope = false;
        for (BenefitRule rule : rules) {
            if (!pickupAllowed(rule, pickup)) {
                continue;
            }
            if (!inTimeWindow(rule, now)) {
                anyInWindow = true;
                continue;
            }
            int limit = rule.getDailyLimit() == null ? 1 : rule.getDailyLimit();
            if (usedToday.getOrDefault(rule.getCode(), 0) >= limit) {
                anyQuota = true;
                continue;
            }
            BigDecimal threshold = rule.getThresholdAmount() == null
                    ? BigDecimal.ZERO : rule.getThresholdAmount();
            if (goods.compareTo(threshold) < 0) {
                anyThreshold = true;
                continue;
            }
            anyScope = true;
        }
        if (anyScope) {
            return "购物车里还没有参与优惠的餐品，试试「金奖豆K咖啡」或「蛋挞甜品」";
        }
        if (anyQuota) {
            return "今日权益次数已用完，明天再来";
        }
        if (anyThreshold) {
            return "差一点就到优惠门槛了，凑单更划算";
        }
        if (anyInWindow) {
            return "当前时段没有可用的权益，下午茶权益 14:00-17:00 生效";
        }
        return "本单暂无可用权益";
    }

    private String valueText(BenefitRule rule) {
        BigDecimal value = rule.getDiscountValue() == null ? BigDecimal.ZERO : rule.getDiscountValue();
        String plain = value.stripTrailingZeros().toPlainString();
        return switch (rule.getBenefitType()) {
            case TYPE_PERCENT_OFF -> value.multiply(BigDecimal.TEN)
                    .stripTrailingZeros().toPlainString() + " 折";
            case TYPE_AMOUNT_OFF -> "立减 " + plain + " 元";
            case TYPE_FIXED_PRICE -> plain + " 元";
            case TYPE_FREE_DELIVERY -> "免配送费";
            default -> plain + " 元";
        };
    }

    private String scopeText(BenefitRule rule, Map<Long, String> categoryNames) {
        if ("ALL".equalsIgnoreCase(rule.getScopeType())) {
            return "全场";
        }
        if (rule.getScopeIds() == null || rule.getScopeIds().isBlank()) {
            return "指定餐品";
        }
        Set<String> names = new LinkedHashSet<>();
        for (String id : rule.getScopeIds().split(",")) {
            String trimmed = id.trim();
            if (trimmed.isEmpty()) {
                continue;
            }
            try {
                names.add(categoryNames.getOrDefault(Long.parseLong(trimmed), "#" + trimmed));
            } catch (NumberFormatException e) {
                names.add("#" + trimmed);
            }
        }
        return String.join(" / ", names);
    }

    private String timeText(BenefitRule rule) {
        if (rule.getStartTime() == null || rule.getEndTime() == null) {
            return "全天";
        }
        return rule.getStartTime() + "-" + rule.getEndTime();
    }

    private Map<Long, String> categoryNames() {
        Map<Long, String> map = new HashMap<>();
        for (Category category : categoryRepository.findAll()) {
            map.put(category.getId(), category.getName());
        }
        return map;
    }

    private String normalizePickup(String pickupType) {
        if (pickupType == null || pickupType.isBlank()) {
            return PICKUP;
        }
        String upper = pickupType.trim().toUpperCase();
        return DELIVERY.equals(upper) ? DELIVERY : PICKUP;
    }

    private BigDecimal scale(BigDecimal value) {
        return (value == null ? BigDecimal.ZERO : value).setScale(2, RoundingMode.HALF_UP);
    }

    /** 一件商品（不是一行购物车）：折扣按件算，才能表达「一杯咖啡 10 元」 */
    private static final class Unit {
        private final Long productId;
        private final String productName;
        private final Long categoryId;
        private final BigDecimal price;
        private boolean used;

        private Unit(Long productId, String productName, Long categoryId, BigDecimal price) {
            this.productId = productId;
            this.productName = productName;
            this.categoryId = categoryId;
            this.price = price == null ? BigDecimal.ZERO : price;
        }
    }
}
