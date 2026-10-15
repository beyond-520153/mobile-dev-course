package com.example.kfc.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 餐品分类模块 —— 控制层 Controller
 *
 * <p>职责：接收 HTTP 请求、参数校验、调用 Service、封装统一响应。
 * <p>禁止：写业务判断、直接访问数据库 / Redis。
 */
@RestController
@RequestMapping("/api/categories")
public class CategoryController {

    // TODO 构造器注入 CategoryService

    // TODO POST   /api/categories          新增
    // TODO GET    /api/categories/{id}     详情
    // TODO GET    /api/categories          分页列表
    // TODO PUT    /api/categories/{id}     修改
    // TODO DELETE /api/categories/{id}     删除
}
