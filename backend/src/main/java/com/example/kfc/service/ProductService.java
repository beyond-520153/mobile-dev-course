package com.example.kfc.service;

import com.example.kfc.domain.dto.ProductDTO;
import com.example.kfc.domain.vo.ProductVO;

import java.util.List;

/**
 * 餐品模块 —— 业务逻辑层 Service 接口
 */
public interface ProductService {

    /**
     * 查询餐品列表
     *
     * @param categoryId 分类筛选，可为 null
     * @param keyword    名称模糊搜索，可为 null
     */
    List<ProductVO> list(Long categoryId, String keyword);

    /** 详情，走 Redis 缓存（10 分钟） */
    ProductVO getById(Long id);

    ProductVO create(ProductDTO dto);

    ProductVO update(Long id, ProductDTO dto);

    void delete(Long id);

    /**
     * 扣减库存（下单时调用）
     *
     * @throws com.example.kfc.common.exception.BusinessException 餐品已下架或库存不足
     */
    void deductStock(Long productId, int quantity);

    /**
     * 回补库存（取消订单时调用）
     *
     * <p>与 {@link #deductStock} 配对：下单锁库存，取消后必须还回去，
     * 否则同一份餐品被反复下单时库存会被凭空吃掉。
     */
    void restoreStock(Long productId, int quantity);
}
