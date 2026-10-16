package com.example.kfc.controller;

import com.example.kfc.common.result.Result;
import com.example.kfc.domain.dto.ProductDTO;
import com.example.kfc.domain.vo.ProductVO;
import com.example.kfc.service.ProductService;
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
 * 餐品模块 —— 控制层 Controller
 */
@RestController
@RequestMapping("/api/products")
public class ProductController {

    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    /**
     * 餐品列表
     *
     * @param categoryId 可选，按分类筛选
     * @param keyword    可选，关键词（名称 / 描述 / 分类名 / 拼音首字母）
     */
    @GetMapping
    public Result<List<ProductVO>> list(@RequestParam(required = false) Long categoryId,
                                       @RequestParam(required = false) String keyword) {
        return Result.success(productService.list(categoryId, keyword));
    }

    /**
     * 搜索餐品
     *
     * <p>与 {@code GET /api/products?keyword=} 等价，单独给搜索框一个语义明确的端点。
     * 路径 {@code /search} 是字面量，Spring 的匹配优先级高于 {@link #getById(Long)} 的
     * 模板 {@code /{id}}，两者不会打架。
     *
     * @param keyword 可选，如「鸡腿堡」「咖啡」「YWJ」；空白表示返回全部上架餐品
     */
    @GetMapping("/search")
    public Result<List<ProductVO>> search(@RequestParam(required = false) String keyword) {
        return Result.success(productService.search(keyword));
    }

    @GetMapping("/{id}")
    public Result<ProductVO> getById(@PathVariable Long id) {
        return Result.success(productService.getById(id));
    }

    @PostMapping
    public Result<ProductVO> create(@Valid @RequestBody ProductDTO dto) {
        return Result.success(productService.create(dto));
    }

    @PutMapping("/{id}")
    public Result<ProductVO> update(@PathVariable Long id, @Valid @RequestBody ProductDTO dto) {
        return Result.success(productService.update(id, dto));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        productService.delete(id);
        return Result.success();
    }
}
