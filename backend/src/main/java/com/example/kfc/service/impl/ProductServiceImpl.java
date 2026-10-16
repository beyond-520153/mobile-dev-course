package com.example.kfc.service.impl;

import com.example.kfc.common.cache.RedisJsonCache;
import com.example.kfc.common.constant.RedisKeyConstants;
import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.dto.ProductDTO;
import com.example.kfc.domain.entity.Product;
import com.example.kfc.domain.vo.ProductVO;
import com.example.kfc.repository.CategoryRepository;
import com.example.kfc.repository.ProductRepository;
import com.example.kfc.service.ProductService;
import com.fasterxml.jackson.core.type.TypeReference;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

/**
 * 餐品模块 —— 业务逻辑层实现
 *
 * <p>缓存策略：详情按 id 缓存 10 分钟；任何写操作同时失效「详情缓存」与「首页分类缓存」。
 */
@Service
public class ProductServiceImpl implements ProductService {

    /** 1 上架 */
    private static final Integer ON_SHELF = 1;

    /** 搜索关键词最长 30 字，超出直接截断（入参要进 LIKE，过长既无意义又白扫表） */
    private static final int MAX_KEYWORD_LENGTH = 30;

    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final RedisJsonCache cache;

    public ProductServiceImpl(ProductRepository productRepository,
                              CategoryRepository categoryRepository,
                              RedisJsonCache cache) {
        this.productRepository = productRepository;
        this.categoryRepository = categoryRepository;
        this.cache = cache;
    }

    @Override
    public List<ProductVO> list(Long categoryId, String keyword) {
        List<Product> rows;
        if (keyword != null && !keyword.isBlank()) {
            rows = searchEntities(keyword);
            if (categoryId != null) {
                rows = rows.stream()
                        .filter(p -> categoryId.equals(p.getCategoryId()))
                        .toList();
            }
        } else if (categoryId != null) {
            rows = productRepository.findByCategoryIdAndStatusOrderBySortOrderAscIdAsc(categoryId, ON_SHELF);
        } else {
            rows = productRepository.findByStatusOrderBySortOrderAscIdAsc(ON_SHELF);
        }
        return rows.stream().map(ProductVO::from).collect(Collectors.toList());
    }

    @Override
    public List<ProductVO> search(String keyword) {
        if (keyword == null || keyword.isBlank()) {
            return list(null, null);
        }
        return searchEntities(keyword).stream().map(ProductVO::from).collect(Collectors.toList());
    }

    /**
     * 关键词裁剪后交给仓储层做四路匹配。
     *
     * <p>只 trim 首尾、不处理中间空格：「香辣 鸡翅」这种输入命中 0 条是合理的，
     * 让用户直观看到没结果，比替他猜意图更省事。
     */
    private List<Product> searchEntities(String keyword) {
        String kw = keyword.trim();
        if (kw.length() > MAX_KEYWORD_LENGTH) {
            kw = kw.substring(0, MAX_KEYWORD_LENGTH);
        }
        return productRepository.search(ON_SHELF, kw);
    }

    @Override
    public ProductVO getById(Long id) {
        String key = RedisKeyConstants.PRODUCT_PREFIX + id;
        ProductVO cached = cache.get(key, new TypeReference<ProductVO>() {
        });
        if (cached != null) {
            return cached;
        }
        ProductVO vo = ProductVO.from(getEntity(id));
        cache.put(key, vo, RedisKeyConstants.PRODUCT_TTL_SECONDS);
        return vo;
    }

    @Override
    @Transactional
    public ProductVO create(ProductDTO dto) {
        requireCategory(dto.getCategoryId());
        Product entity = new Product();
        apply(entity, dto);
        Product saved = productRepository.save(entity);
        evictAfterWrite(saved.getId());
        return ProductVO.from(saved);
    }

    @Override
    @Transactional
    public ProductVO update(Long id, ProductDTO dto) {
        Product entity = getEntity(id);
        requireCategory(dto.getCategoryId());
        apply(entity, dto);
        Product saved = productRepository.save(entity);
        evictAfterWrite(id);
        return ProductVO.from(saved);
    }

    @Override
    @Transactional
    public void delete(Long id) {
        getEntity(id);
        productRepository.deleteById(id);
        evictAfterWrite(id);
    }

    @Override
    @Transactional
    public void deductStock(Long productId, int quantity) {
        Product entity = getEntity(productId);
        if (!ON_SHELF.equals(entity.getStatus())) {
            throw new BusinessException("餐品已下架：" + entity.getName());
        }
        if (entity.getStock() < quantity) {
            throw new BusinessException("库存不足：" + entity.getName() + "，剩余 " + entity.getStock() + " 份");
        }
        entity.setStock(entity.getStock() - quantity);
        productRepository.save(entity);
        evictAfterWrite(productId);
    }

    @Override
    public void restoreStock(Long productId, int quantity) {
        if (quantity <= 0) {
            return;
        }
        // 库存不足会导致下单失败回滚，因此这里总是能取到实体
        Product entity = getEntity(productId);
        entity.setStock(entity.getStock() + quantity);
        productRepository.save(entity);
        evictAfterWrite(productId);
    }

    /** 把 DTO 上的字段写入实体；可选项为 null 时保留原值 */
    private void apply(Product entity, ProductDTO dto) {
        entity.setCategoryId(dto.getCategoryId());
        entity.setName(dto.getName());
        entity.setDescription(dto.getDescription());
        entity.setPrice(dto.getPrice());
        if (dto.getImage() != null) {
            entity.setImage(dto.getImage());
        }
        if (dto.getStock() != null) {
            entity.setStock(dto.getStock());
        }
        if (dto.getSortOrder() != null) {
            entity.setSortOrder(dto.getSortOrder());
        }
        if (dto.getStatus() != null) {
            entity.setStatus(dto.getStatus());
        }
    }

    private void requireCategory(Long categoryId) {
        if (!categoryRepository.existsById(categoryId)) {
            throw new BusinessException("分类不存在：" + categoryId);
        }
    }

    private Product getEntity(Long id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new BusinessException("餐品不存在：" + id));
    }

    private void evictAfterWrite(Long productId) {
        cache.evict(RedisKeyConstants.PRODUCT_PREFIX + productId);
        cache.evict(RedisKeyConstants.CATEGORY_LIST);
    }
}
