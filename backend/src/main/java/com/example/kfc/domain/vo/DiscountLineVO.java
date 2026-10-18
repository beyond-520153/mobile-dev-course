package com.example.kfc.domain.vo;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * 一条优惠明细（结算页 / 订单详情里的一行）
 *
 * <p>例：「大神卡 · 每日 1 杯咖啡 10 元」  −9.00
 */
@Getter
@Setter
public class DiscountLineVO {

    /** 规则编码，取消订单时按它归还次数 */
    private String code;

    /** 规则名，如「每日 1 杯咖啡 10 元」 */
    private String name;

    /** PERCENT_OFF / AMOUNT_OFF / FIXED_PRICE / FREE_DELIVERY */
    private String benefitType;

    /** 规则说明 */
    private String description;

    /** 本单这条规则省了多少钱（正数） */
    private BigDecimal discountAmount;

    /** 命中的餐品，如「拿铁 ×1」；免配送费时为「外送费」 */
    private String itemText;

    /** true 表示这笔优惠抵的是外送费，不是商品金额 */
    private Boolean onDeliveryFee;
}
