package com.example.kfc.repository;

import com.example.kfc.domain.entity.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 订单明细模块 —— 持久化层 Repository
 *
 * <p>职责：只做数据存取，不写业务判断。复杂查询用 @Query 或 Specification。
 */
@Repository
public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {

    // TODO 自定义查询，例如 Optional<OrderItem> findByXxx(String xxx);
}
