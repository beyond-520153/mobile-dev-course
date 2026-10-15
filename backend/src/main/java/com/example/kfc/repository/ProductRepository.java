package com.example.kfc.repository;

import com.example.kfc.domain.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
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

    /** 关键词模糊搜索（只看上架） */
    List<Product> findByStatusAndNameContainingIgnoreCaseOrderBySortOrderAscIdAsc(Integer status, String keyword);
}
