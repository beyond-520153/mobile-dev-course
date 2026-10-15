package com.example.kfc.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 订单模块 —— 控制层 Controller
 *
 * <p>职责：接收 HTTP 请求、参数校验、调用 Service、封装统一响应。
 * <p>禁止：写业务判断、直接访问数据库 / Redis。
 */
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    // TODO 构造器注入 OrderService

    // TODO POST   /api/orders          新增
    // TODO GET    /api/orders/{id}     详情
    // TODO GET    /api/orders          分页列表
    // TODO PUT    /api/orders/{id}     修改
    // TODO DELETE /api/orders/{id}     删除
}
