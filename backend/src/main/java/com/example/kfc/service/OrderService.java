package com.example.kfc.service;

import com.example.kfc.domain.dto.OrderCreateDTO;
import com.example.kfc.domain.enums.OrderStatus;
import com.example.kfc.domain.vo.OrderVO;

import java.util.List;

/**
 * 订单模块 —— 业务逻辑层 Service 接口
 */
public interface OrderService {

    List<OrderVO> listByUser(Long userId);

    List<OrderVO> listAll();

    /** 订单详情（含明细） */
    OrderVO getById(Long id);

    /** 用当前购物车下单：算价 → 生成订单与明细 → 清空购物车 */
    OrderVO create(OrderCreateDTO dto);

    /** 支付：生成取餐码，状态转 PAID */
    OrderVO pay(Long id);

    OrderVO cancel(Long id);

    /** 店员侧状态流转，非法流转会抛业务异常 */
    OrderVO updateStatus(Long id, OrderStatus status);

    void delete(Long id);
}
