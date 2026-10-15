package com.example.kfc.repository;

import com.example.kfc.domain.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 购物车模块 —— 持久化层 Repository
 */
@Repository
public interface CartItemRepository extends JpaRepository<CartItem, Long> {

    List<CartItem> findByUserIdOrderByIdAsc(Long userId);

    /** 同一用户同一餐品只允许一行，加购时用它判断是新增还是累加 */
    Optional<CartItem> findByUserIdAndProductId(Long userId, Long productId);

    /** 带 userId 条件查，防止越权改别人的购物车 */
    Optional<CartItem> findByIdAndUserId(Long id, Long userId);

    void deleteByUserId(Long userId);

    long countByUserId(Long userId);
}
