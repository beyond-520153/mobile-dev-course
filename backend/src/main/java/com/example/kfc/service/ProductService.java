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
     * @param keyword    关键词，可为 null。非空时走 {@link #search(String)} 的四路匹配
     */
    List<ProductVO> list(Long categoryId, String keyword);

    /**
     * 关键词搜索
     *
     * <p>匹配范围：餐品名 / 餐品描述 / 所属分类名 / 名称拼音首字母。
     * 例：「鸡腿堡」命中名称、「香辣」命中描述、「咖啡」命中分类、{@code YWJ} 命中拼音。
     *
     * @param keyword 关键词，空白表示不筛选（返回全部上架餐品）
     */
    List<ProductVO> search(String keyword);

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
