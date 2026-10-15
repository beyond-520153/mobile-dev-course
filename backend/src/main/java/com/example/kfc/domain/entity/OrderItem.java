package com.example.kfc.domain.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 订单明细 —— 领域实体 Domain Entity（PO）
 *
 * <p>当前只保留主键，保证工程可以正常启动；业务字段待数据库设计定稿后补充。
 * <p>建议字段：order_id / product_id / product_name / price / quantity / subtotal
 */
@Getter
@Setter
@Entity
@Table(name = "t_order_item")
public class OrderItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // TODO 补充业务字段

    // TODO 按需补充实体关系，例如 @ManyToOne / @OneToMany
}
