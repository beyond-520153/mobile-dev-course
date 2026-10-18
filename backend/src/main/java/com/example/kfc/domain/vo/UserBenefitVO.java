package com.example.kfc.domain.vo;

import lombok.Getter;
import lombok.Setter;

/**
 * 用户当前可享的会员卡权益（WOW 会员中心 / 大神卡页展示）
 *
 * <p>不只是规则本身，还带上「今天还能用几次」「现在是不是生效时段」，
 * 前端可以直接把不可用的置灰，不用自己算时间和次数。
 */
@Getter
@Setter
public class UserBenefitVO {

    private String code;
    /** GOD 大神卡 / COFFEE 咖啡卡 */
    private String cardType;
    private String name;
    private String benefitType;
    private String description;

    /** 权益力度的展示文案：6 折 / 立减 5.00 元 / 10.00 元 / 免配送费 */
    private String valueText;

    /** 适用范围文案：金奖豆K咖啡 / 全场 */
    private String scopeText;

    /** 时段文案：全天 / 14:00-17:00 */
    private String timeText;

    private Integer dailyLimit;

    /** 今天已用次数 */
    private Integer usedToday;

    /** 今天还剩几次 */
    private Integer remaining;

    /** 当前时间是否在生效时段内（不看次数） */
    private Boolean activeNow;

    /** 现在能不能用：时段内 + 还有次数 */
    private Boolean usable;

    /** 不可用原因，可用时为 null */
    private String unavailableReason;
}
