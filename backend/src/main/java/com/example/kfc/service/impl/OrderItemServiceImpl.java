package com.example.kfc.service.impl;

import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.entity.OrderItem;
import com.example.kfc.domain.vo.OrderItemVO;
import com.example.kfc.repository.OrderItemRepository;
import com.example.kfc.service.OrderItemService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 订单明细模块 —— 业务逻辑层实现
 */
@Service
public class OrderItemServiceImpl implements OrderItemService {

    private final OrderItemRepository orderItemRepository;

    public OrderItemServiceImpl(OrderItemRepository orderItemRepository) {
        this.orderItemRepository = orderItemRepository;
    }

    @Override
    public List<OrderItemVO> listByOrder(Long orderId) {
        return orderItemRepository.findByOrderIdOrderByIdAsc(orderId)
                .stream()
                .map(OrderItemVO::from)
                .collect(Collectors.toList());
    }

    @Override
    public List<OrderItemVO> listByOrders(Collection<Long> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return new ArrayList<>();
        }
        return orderItemRepository.findByOrderIdIn(orderIds)
                .stream()
                .map(OrderItemVO::from)
                .collect(Collectors.toList());
    }

    @Override
    public OrderItemVO getById(Long id) {
        OrderItem entity = orderItemRepository.findById(id)
                .orElseThrow(() -> new BusinessException("订单明细不存在：" + id));
        return OrderItemVO.from(entity);
    }

    @Override
    @Transactional
    public void delete(Long id) {
        if (!orderItemRepository.existsById(id)) {
            throw new BusinessException("订单明细不存在：" + id);
        }
        orderItemRepository.deleteById(id);
    }
}
