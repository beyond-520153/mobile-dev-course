package com.example.kfc.repository;

import com.example.kfc.domain.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 餐品模块 —— 持久化层 Repository
 */
@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {

    /** 全部上架餐品 */
    List<Product> findByStatusOrderBySortOrderAscIdAsc(Integer status);

    /** 某分类下的上架餐品 */
    List<Product> findByCategoryIdAndStatusOrderBySortOrderAscIdAsc(Long categoryId, Integer status);

    /** 某分类下的全部餐品（含下架），删除分类前做占用校验用 */
    List<Product> findByCategoryIdOrderBySortOrderAscIdAsc(Long categoryId);

    boolean existsByCategoryId(Long categoryId);

    /**
     * 关键词搜索：餐品名 / 餐品描述 / 所属分类名 / 名称拼音首字母，四路任一命中即返回（只看上架）。
     *
     * <p>为什么用 JPQL 而不是派生方法名：四个 OR 条件叠起来，方法名会长到没法读。
     * 为什么 join 分类：搜「咖啡」时要能带出「金奖豆K咖啡」整类，光看餐品名做不到。
     * 为什么带 pinyin_initials：让「ywj」也能命中「吮指原味鸡」，这一列由
     * {@code db/migration/V3__product_search.sql} 预计算，不在这里现算。
     *
     * <p>keyword 里的 % 和 _ 会原样进 LIKE，属于有意为之（演示工程不设防注入式通配），
     * 调用方 {@code ProductServiceImpl#search} 已把入参裁剪到 30 字以内。
     */
    @Query("""
            SELECT p FROM Product p, Category c
            WHERE c.id = p.categoryId
              AND p.status = :status
              AND (LOWER(p.name) LIKE LOWER(CONCAT('%', :keyword, '%'))
                OR LOWER(COALESCE(p.description, '')) LIKE LOWER(CONCAT('%', :keyword, '%'))
                OR LOWER(c.name) LIKE LOWER(CONCAT('%', :keyword, '%'))
                OR LOWER(COALESCE(p.pinyinInitials, '')) LIKE LOWER(CONCAT('%', :keyword, '%')))
            ORDER BY p.sortOrder ASC, p.id ASC
            """)
    List<Product> search(@Param("status") Integer status, @Param("keyword") String keyword);
}
