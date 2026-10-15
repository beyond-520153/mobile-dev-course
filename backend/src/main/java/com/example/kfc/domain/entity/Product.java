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
 * 餐品 —— 领域实体 Domain Entity（PO），对应表 t_product
 *
 * <p>分类用 categoryId 显式外键列，不用 @ManyToOne：查询可控、无懒加载坑，
 * 也便于把实体直接当缓存对象序列化。
 */
@Getter
@Setter
@Entity
@Table(name = "t_product")
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 所属分类 */
    @Column(name = "category_id", nullable = false)
    private Long categoryId;

    /** 餐品名 */
    @Column(nullable = false, length = 100)
    private String name;

    /** 描述／口味说明 */
    @Column(length = 500)
    private String description;

    /** 单价，金额统一 BigDecimal，禁止 double */
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    /** 餐品图地址 */
    @Column(length = 255)
    private String image;

    /** 库存，0 表示售罄 */
    @Column(nullable = false)
    private Integer stock;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    /** 1 上架 0 下架 */
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
        if (stock == null) {
            stock = 0;
        }
        if (sortOrder == null) {
            sortOrder = 0;
        }
        if (status == null) {
            status = 1;
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
