package com.example.kfc.repository;

import com.example.kfc.domain.entity.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

/**
 * 订单明细模块 —— 持久化层 Repository
 */
@Repository
public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {

    List<OrderItem> findByOrderIdOrderByIdAsc(Long orderId);

    /** 批量取明细，订单列表页避免 N+1 查询 */
    List<OrderItem> findByOrderIdIn(Collection<Long> orderIds);

    void deleteByOrderId(Long orderId);
}
