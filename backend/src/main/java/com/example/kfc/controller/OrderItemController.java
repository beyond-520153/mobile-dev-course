package com.example.kfc.controller;

import com.example.kfc.common.result.Result;
import com.example.kfc.domain.vo.OrderItemVO;
import com.example.kfc.service.OrderItemService;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 订单明细模块 —— 控制层 Controller
 *
 * <p>明细在下单时由 OrderService 统一写入，这里只暴露查询与单条删除。
 */
@RestController
@RequestMapping("/api/order-items")
public class OrderItemController {

    private final OrderItemService orderItemService;

    public OrderItemController(OrderItemService orderItemService) {
        this.orderItemService = orderItemService;
    }

    @GetMapping
    public Result<List<OrderItemVO>> list(@RequestParam Long orderId) {
        return Result.success(orderItemService.listByOrder(orderId));
    }

    @GetMapping("/{id}")
    public Result<OrderItemVO> getById(@PathVariable Long id) {
        return Result.success(orderItemService.getById(id));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        orderItemService.delete(id);
        return Result.success();
    }
}
