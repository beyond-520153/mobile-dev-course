package com.example.kfc.controller;

import com.example.kfc.common.result.Result;
import com.example.kfc.domain.dto.OrderCreateDTO;
import com.example.kfc.domain.dto.OrderUpdateDTO;
import com.example.kfc.domain.vo.OrderVO;
import com.example.kfc.service.OrderService;
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

import java.util.List;

/**
 * 订单模块 —— 控制层 Controller
 */
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    /** 订单列表；不传 userId 则返回全部（管理端用） */
    @GetMapping
    public Result<List<OrderVO>> list(@RequestParam(required = false) Long userId) {
        return Result.success(userId == null ? orderService.listAll() : orderService.listByUser(userId));
    }

    @GetMapping("/{id}")
    public Result<OrderVO> getById(@PathVariable Long id) {
        return Result.success(orderService.getById(id));
    }

    /** 下单：以该用户当前购物车为准，服务端算价、扣库存、清空购物车 */
    @PostMapping
    public Result<OrderVO> create(@Valid @RequestBody OrderCreateDTO dto) {
        return Result.success(orderService.create(dto));
    }

    /** 店员侧修改订单状态 */
    @PutMapping("/{id}")
    public Result<OrderVO> updateStatus(@PathVariable Long id, @Valid @RequestBody OrderUpdateDTO dto) {
        return Result.success(orderService.updateStatus(id, dto.getStatus()));
    }

    /** 支付：生成取餐码 */
    @PostMapping("/{id}/pay")
    public Result<OrderVO> pay(@PathVariable Long id) {
        return Result.success(orderService.pay(id));
    }

    @PostMapping("/{id}/cancel")
    public Result<OrderVO> cancel(@PathVariable Long id) {
        return Result.success(orderService.cancel(id));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        orderService.delete(id);
        return Result.success();
    }
}
