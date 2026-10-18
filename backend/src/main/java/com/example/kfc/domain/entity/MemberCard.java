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

import java.time.OffsetDateTime;

/**
 * 已开通的会员卡 —— 领域实体 Domain Entity（PO），对应表 t_member_card
 *
 * <p>一个用户可以同时持有多张卡（大神卡 + 咖啡卡），
 * 续费同一类型时不新建记录，而是把当前有效卡的 expireAt 往后叠加。
 */
@Getter
@Setter
@Entity
@Table(name = "t_member_card")
public class MemberCard {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "plan_id", nullable = false)
    private Long planId;

    /** 冗余的卡类型，列表展示不必再关联档位表 */
    @Column(name = "card_type", nullable = false, length = 20)
    private String cardType;

    @Column(name = "card_name", nullable = false, length = 50)
    private String cardName;

    /** 卡号，支付 / 核销用 */
    @Column(name = "card_no", nullable = false, length = 32)
    private String cardNo;

    @Column(name = "start_at", nullable = false)
    private OffsetDateTime startAt;

    @Column(name = "expire_at", nullable = false)
    private OffsetDateTime expireAt;

    /** ACTIVE 生效 / EXPIRED 已过期 */
    @Column(nullable = false, length = 20)
    private String status;

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
            status = "ACTIVE";
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
