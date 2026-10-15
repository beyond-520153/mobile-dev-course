package com.example.kfc.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 购物车项模块 —— 控制层 Controller
 *
 * <p>职责：接收 HTTP 请求、参数校验、调用 Service、封装统一响应。
 * <p>禁止：写业务判断、直接访问数据库 / Redis。
 */
@RestController
@RequestMapping("/api/cart-items")
public class CartItemController {

    // TODO 构造器注入 CartItemService

    // TODO POST   /api/cart-items          新增
    // TODO GET    /api/cart-items/{id}     详情
    // TODO GET    /api/cart-items          分页列表
    // TODO PUT    /api/cart-items/{id}     修改
    // TODO DELETE /api/cart-items/{id}     删除
}
