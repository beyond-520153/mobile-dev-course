package com.example.kfc.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 订单明细模块 —— 控制层 Controller
 *
 * <p>职责：接收 HTTP 请求、参数校验、调用 Service、封装统一响应。
 * <p>禁止：写业务判断、直接访问数据库 / Redis。
 */
@RestController
@RequestMapping("/api/order-items")
public class OrderItemController {

    // TODO 构造器注入 OrderItemService

    // TODO POST   /api/order-items          新增
    // TODO GET    /api/order-items/{id}     详情
    // TODO GET    /api/order-items          分页列表
    // TODO PUT    /api/order-items/{id}     修改
    // TODO DELETE /api/order-items/{id}     删除
}
