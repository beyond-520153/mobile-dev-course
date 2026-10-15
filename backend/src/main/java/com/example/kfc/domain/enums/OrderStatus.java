package com.example.kfc.domain.enums;

/**
 * 订单状态
 *
 * <p>状态流转（MVP 简化版）：
 * PENDING_PAYMENT --pay--> PAID --ready--> READY --complete--> COMPLETED
 * PENDING_PAYMENT / PAID --cancel--> CANCELLED
 */
public enum OrderStatus {

    /** 待支付 */
    PENDING_PAYMENT("待支付"),
    /** 已支付（制作中） */
    PAID("制作中"),
    /** 待取餐 */
    READY("待取餐"),
    /** 已完成 */
    COMPLETED("已完成"),
    /** 已取消 */
    CANCELLED("已取消");

    private final String text;

    OrderStatus(String text) {
        this.text = text;
    }

    /** 前端直接展示的中文文案 */
    public String getText() {
        return text;
    }

    /** 是否允许从当前状态流转到目标状态 */
    public boolean canTransferTo(OrderStatus target) {
        return switch (this) {
            case PENDING_PAYMENT -> target == PAID || target == CANCELLED;
            case PAID -> target == READY || target == CANCELLED;
            case READY -> target == COMPLETED;
            case COMPLETED, CANCELLED -> false;
        };
    }
}
