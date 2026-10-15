package com.example.kfc.repository;

import com.example.kfc.domain.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 餐品分类模块 —— 持久化层 Repository
 *
 * <p>职责：只做数据存取，不写业务判断。
 */
@Repository
public interface CategoryRepository extends JpaRepository<Category, Long> {

    /** 按排序取出启用的分类 */
    List<Category> findByStatusOrderBySortOrderAscIdAsc(Integer status);

    /** 全部分类（含停用），管理端用 */
    List<Category> findAllByOrderBySortOrderAscIdAsc();

    Optional<Category> findByName(String name);

    boolean existsByName(String name);
}
