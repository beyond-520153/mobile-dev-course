package com.example.kfc.controller;

import com.example.kfc.common.result.Result;
import com.example.kfc.domain.dto.CartItemDTO;
import com.example.kfc.domain.dto.CartItemUpdateDTO;
import com.example.kfc.domain.vo.CartItemVO;
import com.example.kfc.service.CartItemService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.List;

/**
 * 购物车模块 —— 控制层 Controller
 */
@RestController
@RequestMapping("/api/cart-items")
public class CartItemController {

    private final CartItemService cartItemService;

    public CartItemController(CartItemService cartItemService) {
        this.cartItemService = cartItemService;
    }

    /** 某个用户的购物车（含餐品快照、小计） */
    @GetMapping
    public Result<List<CartItemVO>> list(@RequestParam Long userId) {
        return Result.success(cartItemService.listByUser(userId));
    }

    /** 购物车件数与合计金额，底部购物车栏用 */
    @GetMapping("/summary")
    public Result<CartSummary> summary(@RequestParam Long userId) {
        CartSummary summary = new CartSummary();
        summary.setCount(cartItemService.countByUser(userId));
        summary.setAmount(cartItemService.sumAmount(userId));
        return Result.success(summary);
    }

    /** 加入购物车：同一餐品已存在则累加 */
    @PostMapping
    public Result<CartItemVO> add(@Valid @RequestBody CartItemDTO dto) {
        return Result.success(cartItemService.add(dto));
    }

    /** 修改数量；数量传 0 等价于删除 */
    @PutMapping("/{id}")
    public Result<CartItemVO> updateQuantity(@PathVariable Long id,
                                             @Valid @RequestBody CartItemUpdateDTO dto) {
        return Result.success(cartItemService.updateQuantity(id, dto.getQuantity()));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id, @RequestParam Long userId) {
        cartItemService.delete(id, userId);
        return Result.success();
    }

    /** 清空购物车 */
    @DeleteMapping
    public Result<Void> clear(@RequestParam Long userId) {
        cartItemService.clear(userId);
        return Result.success();
    }

    /** 购物车汇总出参 */
    public static class CartSummary {
        private Integer count;
        private BigDecimal amount;

        public Integer getCount() {
            return count;
        }

        public void setCount(Integer count) {
            this.count = count;
        }

        public BigDecimal getAmount() {
            return amount;
        }

        public void setAmount(BigDecimal amount) {
            this.amount = amount;
        }
    }
}
