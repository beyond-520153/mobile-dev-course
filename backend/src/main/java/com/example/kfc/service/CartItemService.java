package com.example.kfc.service;

import com.example.kfc.domain.dto.CartItemDTO;
import com.example.kfc.domain.vo.CartItemVO;

import java.math.BigDecimal;
import java.util.List;

/**
 * 购物车模块 —— 业务逻辑层 Service 接口
 *
 * <p>写策略：先落 PostgreSQL（唯一事实来源），再把整份购物车刷新到 Redis 缓存。
 */
public interface CartItemService {

    /** 购物车列表，含餐品快照与金额小计 */
    List<CartItemVO> listByUser(Long userId);

    /** 加入购物车：同一餐品已存在则累加数量 */
    CartItemVO add(CartItemDTO dto);

    /** 修改数量；数量传 0 等价于删除该条目 */
    CartItemVO updateQuantity(Long id, Integer quantity);

    void delete(Long id, Long userId);

    /** 清空该用户购物车 */
    void clear(Long userId);

    /** 购物车商品件数（各条目数量之和） */
    int countByUser(Long userId);

    /** 购物车合计金额 */
    BigDecimal sumAmount(Long userId);
}
