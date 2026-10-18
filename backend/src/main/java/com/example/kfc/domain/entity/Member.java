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
 * 会员账户 —— 领域实体 Domain Entity（PO），对应表 t_member
 *
 * <p>与 t_user 一对一：用户注册后首次访问会员中心时按需创建，
 * 不额外占用注册链路。V金 / 卡券 / 余额 / 成就四项目前由
 * 会员服务自己维护（开卡赠券、支付累计 V金）。
 */
@Getter
@Setter
@Entity
@Table(name = "t_member")
public class Member {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** 会员号，如 80000113 */
    @Column(name = "member_no", nullable = false, length = 32)
    private String memberNo;

    /** 会员昵称，为空时前端回退 t_user.nickname */
    @Column(length = 50)
    private String nickname;

    /** 普通会员 / WOW会员 */
    @Column(name = "level", nullable = false, length = 20)
    private String level;

    /** V金：消费 1 元累计 1 点 */
    @Column(nullable = false)
    private Integer vgold;

    /** 卡券张数 */
    @Column(name = "coupon_count", nullable = false)
    private Integer couponCount;

    /** 账户余额 */
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal balance;

    /** 已点亮成就数 */
    @Column(nullable = false)
    private Integer achievement;

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
        if (level == null) {
            level = "普通会员";
        }
        if (vgold == null) {
            vgold = 0;
        }
        if (couponCount == null) {
            couponCount = 0;
        }
        if (balance == null) {
            balance = BigDecimal.ZERO;
        }
        if (achievement == null) {
            achievement = 0;
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
