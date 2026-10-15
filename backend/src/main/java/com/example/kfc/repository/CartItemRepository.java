package com.example.kfc.repository;

import com.example.kfc.domain.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    /** 购物车行数（只为统计用，渲染给用户的「件数」不要用这个） */
    long countByUserId(Long userId);

    /**
     * 购物车餐品总份数 = sum(quantity)。
     *
     * <p>这是给用户看的「件数」：3 份薯条 + 2 份鸡翅 应显示 5 件而不是 2 行，
     * 必须与订单的 itemCount 口径一致（同样按数量累加）。
     */
    @Query("select coalesce(sum(c.quantity), 0) from CartItem c where c.userId = :userId")
    long sumQuantityByUserId(@Param("userId") Long userId);
}
