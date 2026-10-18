package com.example.kfc.service.impl;

import com.example.kfc.common.constant.RedisKeyConstants;
import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.dto.CartItemDTO;
import com.example.kfc.domain.entity.CartItem;
import com.example.kfc.domain.vo.CartItemVO;
import com.example.kfc.domain.vo.ProductVO;
import com.example.kfc.repository.CartItemRepository;
import com.example.kfc.service.CartItemService;
import com.example.kfc.service.ProductService;
import com.example.kfc.service.UserService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 购物车模块 —— 业务逻辑层实现
 *
 * <p>两层数据库的分工：
 * <ul>
 *   <li>PostgreSQL 是唯一事实来源，增删改先落库，事务成功才算成功；</li>
 *   <li>Redis Hash（kfc:cart:{userId}）作为缓存副本，每次写库后整份刷新，7 天过期。</li>
 * </ul>
 * Redis 挂了不影响功能，只会退化成每次都查库。
 */
@Service
public class CartItemServiceImpl implements CartItemService {

    private static final Logger log = LoggerFactory.getLogger(CartItemServiceImpl.class);

    private final CartItemRepository cartItemRepository;
    private final ProductService productService;
    private final UserService userService;
    private final StringRedisTemplate redis;

    public CartItemServiceImpl(CartItemRepository cartItemRepository,
                               ProductService productService,
                               UserService userService,
                               StringRedisTemplate redis) {
        this.cartItemRepository = cartItemRepository;
        this.productService = productService;
        this.userService = userService;
        this.redis = redis;
    }

    @Override
    public List<CartItemVO> listByUser(Long userId) {
        List<CartItem> rows = cartItemRepository.findByUserIdOrderByIdAsc(userId);
        if (rows.isEmpty()) {
            return new ArrayList<>();
        }
        // 一次性把用到的餐品查出来，避免循环里逐个查产生 N+1
        Map<Long, ProductVO> products = rows.stream()
                .map(CartItem::getProductId)
                .distinct()
                .map(productService::getById)
                .collect(Collectors.toMap(ProductVO::getId, Function.identity(), (a, b) -> a));

        List<CartItemVO> result = new ArrayList<>(rows.size());
        for (CartItem row : rows) {
            ProductVO p = products.get(row.getProductId());
            if (p != null) {
                result.add(toVO(row, p));
            }
        }
        return result;
    }

    @Override
    @Transactional
    public CartItemVO add(CartItemDTO dto) {
        userService.getById(dto.getUserId());
        ProductVO product = productService.getById(dto.getProductId());
        if (!Integer.valueOf(1).equals(product.getStatus())) {
            throw new BusinessException("餐品已下架：" + product.getName());
        }

        CartItem entity = cartItemRepository
                .findByUserIdAndProductId(dto.getUserId(), dto.getProductId())
                .orElseGet(() -> {
                    CartItem created = new CartItem();
                    created.setUserId(dto.getUserId());
                    created.setProductId(dto.getProductId());
                    created.setQuantity(0);
                    return created;
                });

        int target = entity.getQuantity() + dto.getQuantity();
        if (product.getStock() != null && target > product.getStock()) {
            throw new BusinessException("库存不足，最多还能加 " + (product.getStock() - entity.getQuantity()) + " 份");
        }
        entity.setQuantity(target);
        CartItem saved = cartItemRepository.save(entity);
        refreshCache(dto.getUserId());
        return toVO(saved, product);
    }

    @Override
    @Transactional
    public CartItemVO updateQuantity(Long id, Integer quantity) {
        CartItem entity = cartItemRepository.findById(id)
                .orElseThrow(() -> new BusinessException("购物车条目不存在：" + id));

        if (quantity == null || quantity <= 0) {
            cartItemRepository.delete(entity);
            refreshCache(entity.getUserId());
            return null;
        }

        ProductVO product = productService.getById(entity.getProductId());
        if (product.getStock() != null && quantity > product.getStock()) {
            throw new BusinessException("库存不足，最多 " + product.getStock() + " 份");
        }
        entity.setQuantity(quantity);
        CartItem saved = cartItemRepository.save(entity);
        refreshCache(entity.getUserId());
        return toVO(saved, product);
    }

    @Override
    @Transactional
    public void delete(Long id, Long userId) {
        CartItem entity = cartItemRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new BusinessException("购物车条目不存在或不属于该用户"));
        cartItemRepository.delete(entity);
        refreshCache(userId);
    }

    @Override
    @Transactional
    public void clear(Long userId) {
        cartItemRepository.deleteByUserId(userId);
        try {
            redis.delete(RedisKeyConstants.CART_PREFIX + userId);
        } catch (Exception e) {
            log.warn("清空购物车缓存失败：{}", e.getMessage());
        }
    }

    @Override
    public int countByUser(Long userId) {
        // 按份数累加，不用行数：口径要和订单的 itemCount 一致，
        // 否则「已选 N 件」和下单后的「共 M 件」会对不上。
        return (int) cartItemRepository.sumQuantityByUserId(userId);
    }

    @Override
    public BigDecimal sumAmount(Long userId) {
        return listByUser(userId).stream()
                .map(CartItemVO::getSubtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /** 把整份购物车刷到 Redis Hash：field = productId，value = quantity */
    private void refreshCache(Long userId) {
        String key = RedisKeyConstants.CART_PREFIX + userId;
        try {
            redis.delete(key);
            List<CartItem> rows = cartItemRepository.findByUserIdOrderByIdAsc(userId);
            if (!rows.isEmpty()) {
                Map<String, String> hash = rows.stream().collect(Collectors.toMap(
                        r -> String.valueOf(r.getProductId()),
                        r -> String.valueOf(r.getQuantity()),
                        (a, b) -> a));
                redis.opsForHash().putAll(key, hash);
            }
            redis.expire(key, Duration.ofSeconds(RedisKeyConstants.CART_TTL_SECONDS));
        } catch (Exception e) {
            log.warn("刷新购物车缓存失败，不影响主流程：{}", e.getMessage());
        }
    }

    private CartItemVO toVO(CartItem entity, ProductVO product) {
        CartItemVO vo = new CartItemVO();
        vo.setId(entity.getId());
        vo.setUserId(entity.getUserId());
        vo.setProductId(entity.getProductId());
        vo.setCategoryId(product.getCategoryId());
        vo.setProductName(product.getName());
        vo.setProductImage(product.getImage());
        vo.setPrice(product.getPrice());
        vo.setQuantity(entity.getQuantity());
        vo.setSubtotal(product.getPrice().multiply(BigDecimal.valueOf(entity.getQuantity())));
        vo.setStock(product.getStock());
        vo.setProductStatus(product.getStatus());
        return vo;
    }
}
