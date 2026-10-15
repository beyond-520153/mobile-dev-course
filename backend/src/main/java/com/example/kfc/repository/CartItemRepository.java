package com.example.kfc.repository;

import com.example.kfc.domain.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 购物车项模块 —— 持久化层 Repository
 *
 * <p>职责：只做数据存取，不写业务判断。复杂查询用 @Query 或 Specification。
 */
@Repository
public interface CartItemRepository extends JpaRepository<CartItem, Long> {

    // TODO 自定义查询，例如 Optional<CartItem> findByXxx(String xxx);
}
