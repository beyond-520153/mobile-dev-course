package com.example.kfc.service;

import com.example.kfc.domain.dto.CategoryDTO;
import com.example.kfc.domain.vo.CategoryVO;

import java.util.List;

/**
 * 餐品分类模块 —— 业务逻辑层 Service 接口
 */
public interface CategoryService {

    /** 点餐首页用：分类 + 各自分类下在售餐品，走 Redis 缓存 */
    List<CategoryVO> listWithProducts();

    CategoryVO getById(Long id);

    CategoryVO create(CategoryDTO dto);

    CategoryVO update(Long id, CategoryDTO dto);

    /** 分类下还有餐品时拒绝删除 */
    void delete(Long id);

    /** 清掉首页分类缓存 */
    void evictCache();
}
