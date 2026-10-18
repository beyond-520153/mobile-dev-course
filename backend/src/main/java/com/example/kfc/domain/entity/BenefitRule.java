package com.example.kfc.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.time.OffsetDateTime;

/**
 * 会员卡权益规则 —— 领域实体 Domain Entity（PO），对应表 t_benefit_rule
 *
 * <p>把「优惠怎么算」写成数据而不是 if-else：
 * 折扣率、立减额、特价、免配送费四种算法共用一张表，
 * 官方调规则时只改数据（营业侧可配），不用发版。
 *
 * <p>四种 benefitType：
 * <ul>
 *   <li>{@code PERCENT_OFF} 折扣：discountValue = 0.60 表示 6 折，可配 maxDiscount 封顶；</li>
 *   <li>{@code AMOUNT_OFF} 立减：discountValue = 5.00，可配 thresholdAmount 门槛；</li>
 *   <li>{@code FIXED_PRICE} 特价：discountValue = 10.00，只对原价高于它的餐品生效；</li>
 *   <li>{@code FREE_DELIVERY} 免配送费：把外送费抵掉，走 thresholdAmount 门槛。</li>
 * </ul>
 */
@Getter
@Setter
@Entity
@Table(name = "t_benefit_rule")
public class BenefitRule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 规则编码，订单上按编码记流水 */
    @Column(nullable = false, length = 32)
    private String code;

    /** GOD 大神卡 / COFFEE 咖啡卡 */
    @Column(name = "card_type", nullable = false, length = 20)
    private String cardType;

    @Column(nullable = false, length = 50)
    private String name;

    /** PERCENT_OFF / AMOUNT_OFF / FIXED_PRICE / FREE_DELIVERY */
    @Column(name = "benefit_type", nullable = false, length = 20)
    private String benefitType;

    /** CATEGORY 按分类匹配 / ALL 全场 */
    @Column(name = "scope_type", nullable = false, length = 20)
    private String scopeType;

    /** 分类 id 列表，逗号分隔 */
    @Column(name = "scope_ids", length = 200)
    private String scopeIds;

    /** 需凑够几件才生效（「两件套」= 2） */
    @Column(name = "min_quantity", nullable = false)
    private Integer minQuantity;

    /** 商品金额门槛 */
    @Column(name = "threshold_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal thresholdAmount;

    /** 折扣率 / 立减额 / 特价 */
    @Column(name = "discount_value", nullable = false, precision = 10, scale = 2)
    private BigDecimal discountValue;

    /** 单次优惠封顶，null 不封顶 */
    @Column(name = "max_discount", precision = 10, scale = 2)
    private BigDecimal maxDiscount;

    /** 生效时段，两个都为空表示全天 */
    @Column(name = "start_time")
    private LocalTime startTime;

    @Column(name = "end_time")
    private LocalTime endTime;

    /** 每人每日可用次数 */
    @Column(name = "daily_limit", nullable = false)
    private Integer dailyLimit;

    /** 适用的取餐方式，逗号分隔 */
    @Column(name = "pickup_types", nullable = false, length = 40)
    private String pickupTypes;

    @Column(length = 255)
    private String description;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    /** 1 生效 0 停用 */
    @Column(nullable = false)
    private Integer status;

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
            status = 1;
        }
        if (minQuantity == null) {
            minQuantity = 1;
        }
        if (dailyLimit == null) {
            dailyLimit = 1;
        }
        if (sortOrder == null) {
            sortOrder = 0;
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
