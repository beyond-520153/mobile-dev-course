package com.example.kfc.service.impl;

import com.example.kfc.common.cache.RedisJsonCache;
import com.example.kfc.common.constant.RedisKeyConstants;
import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.dto.CategoryDTO;
import com.example.kfc.domain.entity.Category;
import com.example.kfc.domain.entity.Product;
import com.example.kfc.domain.vo.CategoryVO;
import com.example.kfc.domain.vo.ProductVO;
import com.example.kfc.repository.CategoryRepository;
import com.example.kfc.repository.ProductRepository;
import com.example.kfc.service.CategoryService;
import com.fasterxml.jackson.core.type.TypeReference;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 餐品分类模块 —— 业务逻辑层实现
 */
@Service
public class CategoryServiceImpl implements CategoryService {

    /** 1 启用 / 上架 */
    private static final Integer ENABLED = 1;

    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final RedisJsonCache cache;

    public CategoryServiceImpl(CategoryRepository categoryRepository,
                               ProductRepository productRepository,
                               RedisJsonCache cache) {
        this.categoryRepository = categoryRepository;
        this.productRepository = productRepository;
        this.cache = cache;
    }

    @Override
    public List<CategoryVO> listWithProducts() {
        List<CategoryVO> cached = cache.get(RedisKeyConstants.CATEGORY_LIST,
                new TypeReference<List<CategoryVO>>() {
                });
        if (cached != null) {
            return cached;
        }
        List<CategoryVO> result = buildFromDb();
        cache.put(RedisKeyConstants.CATEGORY_LIST, result, RedisKeyConstants.CATEGORY_TTL_SECONDS);
        return result;
    }

    /** 从数据库拼「分类 + 该分类在售餐品」 */
    private List<CategoryVO> buildFromDb() {
        List<Category> categories = categoryRepository.findByStatusOrderBySortOrderAscIdAsc(ENABLED);
        Map<Long, List<Product>> grouped = productRepository
                .findByStatusOrderBySortOrderAscIdAsc(ENABLED)
                .stream()
                .collect(Collectors.groupingBy(Product::getCategoryId));

        return categories.stream().map(c -> {
            CategoryVO vo = CategoryVO.from(c);
            vo.setProducts(grouped.getOrDefault(c.getId(), List.of())
                    .stream()
                    .map(ProductVO::from)
                    .collect(Collectors.toList()));
            return vo;
        }).collect(Collectors.toList());
    }

    @Override
    public CategoryVO getById(Long id) {
        return CategoryVO.from(getEntity(id));
    }

    @Override
    @Transactional
    public CategoryVO create(CategoryDTO dto) {
        if (categoryRepository.existsByName(dto.getName())) {
            throw new BusinessException("分类已存在：" + dto.getName());
        }
        Category entity = new Category();
        entity.setName(dto.getName());
        entity.setSortOrder(dto.getSortOrder());
        entity.setIcon(dto.getIcon());
        entity.setStatus(dto.getStatus());
        Category saved = categoryRepository.save(entity);
        evictCache();
        return CategoryVO.from(saved);
    }

    @Override
    @Transactional
    public CategoryVO update(Long id, CategoryDTO dto) {
        Category entity = getEntity(id);
        if (!entity.getName().equals(dto.getName()) && categoryRepository.existsByName(dto.getName())) {
            throw new BusinessException("分类已存在：" + dto.getName());
        }
        entity.setName(dto.getName());
        if (dto.getSortOrder() != null) {
            entity.setSortOrder(dto.getSortOrder());
        }
        if (dto.getIcon() != null) {
            entity.setIcon(dto.getIcon());
        }
        if (dto.getStatus() != null) {
            entity.setStatus(dto.getStatus());
        }
        Category saved = categoryRepository.save(entity);
        evictCache();
        return CategoryVO.from(saved);
    }

    @Override
    @Transactional
    public void delete(Long id) {
        getEntity(id);
        if (productRepository.existsByCategoryId(id)) {
            throw new BusinessException("该分类下还有餐品，请先移除或改挂其它分类");
        }
        categoryRepository.deleteById(id);
        evictCache();
    }

    @Override
    public void evictCache() {
        cache.evict(RedisKeyConstants.CATEGORY_LIST);
    }

    /** 取实体，不存在直接抛业务异常 */
    private Category getEntity(Long id) {
        return categoryRepository.findById(id)
                .orElseThrow(() -> new BusinessException("分类不存在：" + id));
    }
}
