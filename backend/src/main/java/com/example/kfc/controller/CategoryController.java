package com.example.kfc.controller;

import com.example.kfc.common.result.Result;
import com.example.kfc.domain.dto.CategoryDTO;
import com.example.kfc.domain.vo.CategoryVO;
import com.example.kfc.service.BenefitService;
import com.example.kfc.service.CategoryService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 餐品分类模块 —— 控制层 Controller
 */
@RestController
@RequestMapping("/api/categories")
public class CategoryController {

    private final CategoryService categoryService;
    private final BenefitService benefitService;

    public CategoryController(CategoryService categoryService, BenefitService benefitService) {
        this.categoryService = categoryService;
        this.benefitService = benefitService;
    }

    /** 点餐首页：分类 + 各自分类下在售餐品（走 Redis 缓存） */
    @GetMapping({"", "/tree"})
    public Result<List<CategoryVO>> list() {
        List<CategoryVO> categories = categoryService.listWithProducts();
        // 点餐页是会员价最主要的展示位：缓存里只有基础价，会员价在这里按当前用户叠加
        for (CategoryVO category : categories) {
            benefitService.fillMemberPrice(category.getProducts());
        }
        return Result.success(categories);
    }

    @GetMapping("/{id}")
    public Result<CategoryVO> getById(@PathVariable Long id) {
        return Result.success(categoryService.getById(id));
    }

    @PostMapping
    public Result<CategoryVO> create(@Valid @RequestBody CategoryDTO dto) {
        return Result.success(categoryService.create(dto));
    }

    @PutMapping("/{id}")
    public Result<CategoryVO> update(@PathVariable Long id, @Valid @RequestBody CategoryDTO dto) {
        return Result.success(categoryService.update(id, dto));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        categoryService.delete(id);
        return Result.success();
    }
}
