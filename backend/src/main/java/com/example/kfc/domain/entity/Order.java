package com.example.kfc.domain.entity;

import com.example.kfc.domain.enums.OrderStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * 订单主表 —— 领域实体 Domain Entity（PO），对应表 t_order
 */
@Getter
@Setter
@Entity
@Table(name = "t_order")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 业务订单号，如 202610152056301234 */
    @Column(name = "order_no", nullable = false, length = 32)
    private String orderNo;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** 到店自取时为 null */
    @Column(name = "address_id")
    private Long addressId;

    /** 取餐方式：PICKUP 到店自取 / DELIVERY 外送 */
    @Column(name = "pickup_type", nullable = false, length = 20)
    private String pickupType;

    /** 商品总额 */
    @Column(name = "total_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal totalAmount;

    /** 外送费（到店自取为 0） */
    @Column(name = "delivery_fee", nullable = false, precision = 10, scale = 2)
    private BigDecimal deliveryFee;

    /** 会员卡权益优惠合计（商品优惠 + 外送费减免） */
    @Column(name = "discount_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal discountAmount;

    /** 实付金额 = totalAmount + deliveryFee - discountAmount */
    @Column(name = "pay_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal payAmount;

    /** 本单用掉的权益规则编码，逗号分隔（取消订单时按它把次数还回去） */
    @Column(name = "benefit_codes", length = 200)
    private String benefitCodes;

    /** 优惠文案，直接给前端展示 */
    @Column(name = "benefit_detail", length = 500)
    private String benefitDetail;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OrderStatus status;

    /** 备注，如「不要生菜」 */
    @Column(length = 255)
    private String remark;

    /** 取餐码，支付后生成 */
    @Column(name = "pickup_code", length = 10)
    private String pickupCode;

    @Column(name = "pay_time")
    private OffsetDateTime payTime;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        OffsetDateTime now = OffsetDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
        if (status == null) {
            status = OrderStatus.PENDING_PAYMENT;
        }
        if (pickupType == null) {
            pickupType = "PICKUP";
        }
        if (deliveryFee == null) {
            deliveryFee = BigDecimal.ZERO;
        }
        if (discountAmount == null) {
            discountAmount = BigDecimal.ZERO;
        }
        if (payAmount == null) {
            payAmount = totalAmount == null ? BigDecimal.ZERO : totalAmount;
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
