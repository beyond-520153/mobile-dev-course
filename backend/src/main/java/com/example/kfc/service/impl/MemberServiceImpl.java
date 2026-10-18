package com.example.kfc.service.impl;

import com.example.kfc.common.cache.RedisJsonCache;
import com.example.kfc.common.constant.RedisKeyConstants;
import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.dto.MemberOpenDTO;
import com.example.kfc.domain.entity.Member;
import com.example.kfc.domain.entity.MemberCard;
import com.example.kfc.domain.entity.MemberPlan;
import com.example.kfc.domain.vo.MemberCardVO;
import com.example.kfc.domain.vo.MemberPlanVO;
import com.example.kfc.domain.vo.MemberSummaryVO;
import com.example.kfc.repository.MemberCardRepository;
import com.example.kfc.repository.MemberPlanRepository;
import com.example.kfc.repository.MemberRepository;
import com.example.kfc.service.MemberService;
import com.example.kfc.service.UserService;
import com.fasterxml.jackson.core.type.TypeReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

/**
 * 会员模块 —— 业务逻辑层实现
 *
 * <p>两层数据库的分工和订单模块保持一致：
 * Redis 只放「会员概要」这种读多写少、算起来还要连表的聚合结果（60 秒 TTL），
 * 事实数据（账户、卡、档位）一律在 PostgreSQL。
 *
 * <p>开通／续费的规则：
 * <ul>
 *   <li>同一类型（大神卡 / 咖啡卡）只保留一张生效中的卡，续费直接在当前卡的到期日上叠加月数；</li>
 *   <li>开卡成功赠 2 张卡券（couponCount += 2），把「卡券」这一格填成有意义的数；</li>
 *   <li>持有任意生效卡，会员等级即升为 WOW会员。</li>
 * </ul>
 */
@Service
public class MemberServiceImpl implements MemberService {

    private static final Logger log = LoggerFactory.getLogger(MemberServiceImpl.class);

    private static final String STATUS_ACTIVE = "ACTIVE";
    private static final String STATUS_EXPIRED = "EXPIRED";
    private static final String LEVEL_WOW = "WOW会员";
    private static final String LEVEL_NORMAL = "普通会员";
    private static final int COUPONS_PER_OPEN = 2;
    private static final DateTimeFormatter CARD_NO_FORMAT = DateTimeFormatter.ofPattern("yyMMddHHmmss");

    private final MemberRepository memberRepository;
    private final MemberCardRepository cardRepository;
    private final MemberPlanRepository planRepository;
    private final UserService userService;
    private final RedisJsonCache cache;

    public MemberServiceImpl(MemberRepository memberRepository,
                             MemberCardRepository cardRepository,
                             MemberPlanRepository planRepository,
                             UserService userService,
                             RedisJsonCache cache) {
        this.memberRepository = memberRepository;
        this.cardRepository = cardRepository;
        this.planRepository = planRepository;
        this.userService = userService;
        this.cache = cache;
    }

    @Override
    public MemberSummaryVO getSummary(Long userId) {
        if (userId == null) {
            throw new BusinessException("用户 id 不能为空");
        }
        String key = RedisKeyConstants.MEMBER_SUMMARY_PREFIX + userId;
        MemberSummaryVO cached = cache.get(key, new TypeReference<MemberSummaryVO>() {
        });
        if (cached != null) {
            return cached;
        }
        MemberSummaryVO vo = buildSummary(userId);
        cache.put(key, vo, RedisKeyConstants.MEMBER_SUMMARY_TTL_SECONDS);
        return vo;
    }

    @Override
    public List<MemberCardVO> listCards(Long userId) {
        if (userId == null) {
            throw new BusinessException("用户 id 不能为空");
        }
        return activeCards(userId);
    }

    @Override
    public List<MemberPlanVO> listPlans(String cardType) {
        List<MemberPlan> plans;
        if (cardType == null || cardType.isBlank()) {
            plans = planRepository.findByStatusOrderBySortOrderAsc(1);
        } else {
            plans = planRepository.findByCardTypeAndStatusOrderBySortOrderAsc(cardType.toUpperCase(), 1);
        }
        return plans.stream().map(MemberPlanVO::from).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public MemberSummaryVO openCard(MemberOpenDTO dto) {
        userService.getById(dto.getUserId());

        MemberPlan plan = planRepository.findByCode(dto.getPlanCode())
                .orElseThrow(() -> new BusinessException("套餐不存在：" + dto.getPlanCode()));
        if (!Integer.valueOf(1).equals(plan.getStatus())) {
            throw new BusinessException("该套餐已下架：" + plan.getName());
        }

        Member member = getOrCreate(dto.getUserId());
        OffsetDateTime now = OffsetDateTime.now();
        OffsetDateTime base = now;

        MemberCard exist = cardRepository
                .findFirstByUserIdAndCardTypeAndStatusOrderByExpireAtDesc(
                        dto.getUserId(), plan.getCardType(), STATUS_ACTIVE)
                .orElse(null);

        if (exist != null && exist.getExpireAt() != null && exist.getExpireAt().isAfter(now)) {
            // 续费：从当前到期日往后叠加，不吞掉剩余天数
            base = exist.getExpireAt();
            exist.setExpireAt(base.plusMonths(plan.getMonths()));
            exist.setPlanId(plan.getId());
            exist.setCardName(plan.getName());
            cardRepository.save(exist);
            log.info("会员卡续费：userId={}，类型={}，新到期={}", dto.getUserId(), plan.getCardType(), exist.getExpireAt());
        } else {
            if (exist != null) {
                exist.setStatus(STATUS_EXPIRED);
                cardRepository.save(exist);
            }
            MemberCard card = new MemberCard();
            card.setUserId(dto.getUserId());
            card.setPlanId(plan.getId());
            card.setCardType(plan.getCardType());
            card.setCardName(plan.getName());
            card.setCardNo(generateCardNo());
            card.setStartAt(base);
            card.setExpireAt(base.plusMonths(plan.getMonths()));
            card.setStatus(STATUS_ACTIVE);
            cardRepository.save(card);
            log.info("会员卡开通：userId={}，套餐={}，到期={}", dto.getUserId(), plan.getCode(), card.getExpireAt());
        }

        member.setCouponCount(member.getCouponCount() + COUPONS_PER_OPEN);
        member.setLevel(LEVEL_WOW);
        memberRepository.save(member);

        evict(dto.getUserId());
        return buildSummary(dto.getUserId());
    }

    @Override
    @Transactional
    public void accrueVgold(Long userId, BigDecimal amount) {
        if (userId == null || amount == null || amount.signum() <= 0) {
            return;
        }
        try {
            Member member = getOrCreate(userId);
            member.setVgold(member.getVgold() + amount.intValue());
            memberRepository.save(member);
            evict(userId);
            log.debug("累计 V金：userId={}，+{}，当前={}", userId, amount.intValue(), member.getVgold());
        } catch (Exception e) {
            // V金只是权益，累计失败不能影响支付；记一条 warn 便于事后补
            log.warn("累计 V金失败，已跳过。userId={}，amount={}，原因={}", userId, amount, e.getMessage());
        }
    }

    /* ------------------------------ 内部方法 ------------------------------ */

    /** 汇总一次概要：账户 + 生效卡（Redis 未命中时走这里） */
    private MemberSummaryVO buildSummary(Long userId) {
        Member member = getOrCreate(userId);
        List<MemberCardVO> cards = activeCards(userId);

        MemberSummaryVO vo = MemberSummaryVO.from(member);
        vo.setCards(cards);
        boolean hasCard = !cards.isEmpty();
        vo.setHasCard(hasCard);
        vo.setLevel(hasCard ? LEVEL_WOW : LEVEL_NORMAL);

        // 等级是算出来的，顺手把落库值对齐，避免库里长期停在「普通会员」
        if (!vo.getLevel().equals(member.getLevel())) {
            member.setLevel(vo.getLevel());
            memberRepository.save(member);
        }
        return vo;
    }

    /** 生效中的卡；顺手把已过期的记录标成 EXPIRED */
    private List<MemberCardVO> activeCards(Long userId) {
        List<MemberCard> cards = cardRepository
                .findByUserIdAndStatusOrderByExpireAtDesc(userId, STATUS_ACTIVE);
        List<MemberCardVO> result = new ArrayList<>(cards.size());
        OffsetDateTime now = OffsetDateTime.now();
        for (MemberCard card : cards) {
            if (card.getExpireAt() != null && card.getExpireAt().isBefore(now)) {
                card.setStatus(STATUS_EXPIRED);
                cardRepository.save(card);
                continue;
            }
            result.add(MemberCardVO.from(card));
        }
        return result;
    }

    /** 取账户，没有就按用户 id 生成一个（会员号规则与 V4 脚本一致） */
    private Member getOrCreate(Long userId) {
        return memberRepository.findByUserId(userId).orElseGet(() -> {
            Member member = new Member();
            member.setUserId(userId);
            member.setMemberNo(String.valueOf(80000000L + userId * 113L));
            member.setLevel(LEVEL_NORMAL);
            member.setVgold(0);
            member.setCouponCount(0);
            member.setBalance(BigDecimal.ZERO);
            member.setAchievement(0);
            return memberRepository.save(member);
        });
    }

    private void evict(Long userId) {
        cache.evict(RedisKeyConstants.MEMBER_SUMMARY_PREFIX + userId);
    }

    /** 卡号：GC + 时间戳 + 3 位随机，撞号重试 */
    private String generateCardNo() {
        for (int i = 0; i < 5; i++) {
            String candidate = "GC" + OffsetDateTime.now().format(CARD_NO_FORMAT)
                    + ThreadLocalRandom.current().nextInt(100, 999);
            if (!cardRepository.existsByCardNo(candidate)) {
                return candidate;
            }
        }
        throw new BusinessException("卡号生成失败，请重试");
    }
}
