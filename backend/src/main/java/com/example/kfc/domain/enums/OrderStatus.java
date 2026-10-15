package com.example.kfc.domain.enums;

/**
 * 订单状态
 * TODO 状态流转规则待业务确认
 */
public enum OrderStatus {

    /** 待支付 */
    PENDING_PAYMENT,
    /** 已支付 */
    PAID,
    /** 制作中 */
    PREPARING,
    /** 待取餐 */
    READY,
    /** 已完成 */
    COMPLETED,
    /** 已取消 */
    CANCELLED
}
