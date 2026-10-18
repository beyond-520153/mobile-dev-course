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
import java.time.OffsetDateTime;

/**
 * 会员卡可售档位 —— 领域实体 Domain Entity（PO），对应表 t_member_plan
 *
 * <p>档位是「商品」，会员卡是「已购实例」；价格与有效月数都放在这里，
 * 开卡时按 months 算到期时间，避免把时间规则写死在业务代码里。
 */
@Getter
@Setter
@Entity
@Table(name = "t_member_plan")
public class MemberPlan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 档位编码：GOD_MONTH / GOD_SEASON / GOD_YEAR / COFFEE_30 */
    @Column(nullable = false, length = 32)
    private String code;

    /** GOD 大神卡 / COFFEE 咖啡卡 */
    @Column(name = "card_type", nullable = false, length = 20)
    private String cardType;

    /** 展示名：月卡 / 季卡 / 年卡 / 咖啡卡 · 30天 */
    @Column(nullable = false, length = 50)
    private String name;

    /** 有效月数 */
    @Column(nullable = false)
    private Integer months;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    @Column(name = "origin_price", nullable = false, precision = 10, scale = 2)
    private BigDecimal originPrice;

    /** 特权条数，前端「11 特权 / 8 特权」标题用 */
    @Column(name = "privilege_num", nullable = false)
    private Integer privilegeNum;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    /** 1 在售 0 下架 */
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
        if (sortOrder == null) {
            sortOrder = 0;
        }
        if (privilegeNum == null) {
            privilegeNum = 0;
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
