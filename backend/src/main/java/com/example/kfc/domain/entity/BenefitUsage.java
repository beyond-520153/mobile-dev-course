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

import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * 权益使用流水 —— 领域实体 Domain Entity（PO），对应表 t_benefit_usage
 *
 * <p>用户 + 规则 + 日期唯一，当计数器用：
 * 「每日 1 杯咖啡 10 元」就是查今天的 usedCount 是否已到 dailyLimit。
 * 订单取消时把对应规则当天的计数减回去（见 BenefitService#release）。
 */
@Getter
@Setter
@Entity
@Table(name = "t_benefit_usage")
public class BenefitUsage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "rule_code", nullable = false, length = 32)
    private String ruleCode;

    /** 自然日，按东八区算 */
    @Column(name = "use_date", nullable = false)
    private LocalDate useDate;

    @Column(name = "used_count", nullable = false)
    private Integer usedCount;

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
        if (usedCount == null) {
            usedCount = 0;
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
