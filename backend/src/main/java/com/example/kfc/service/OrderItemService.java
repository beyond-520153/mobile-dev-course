package com.example.kfc.service;

import com.example.kfc.domain.vo.OrderItemVO;

import java.util.Collection;
import java.util.List;

/**
 * 订单明细模块 —— 业务逻辑层 Service 接口
 *
 * <p>订单明细在领域上属于「订单聚合」，因此下单时的写入由 OrderService 统一完成，
 * 本接口只提供对外查询与单条维护能力。
 */
public interface OrderItemService {

    List<OrderItemVO> listByOrder(Long orderId);

    List<OrderItemVO> listByOrders(Collection<Long> orderIds);

    OrderItemVO getById(Long id);

    void delete(Long id);
}
