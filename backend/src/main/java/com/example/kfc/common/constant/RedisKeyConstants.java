package com.example.kfc.common.constant;

/**
 * Redis key 统一在这里定义，避免各处硬拼字符串
 *
 * <p>命名规范：kfc:{业务}:{标识}
 */
public final class RedisKeyConstants {

    private RedisKeyConstants() {
    }

    /** 登录 token：kfc:token:{userId} */
    public static final String TOKEN_PREFIX = "kfc:token:";

    /** 购物车 Hash：kfc:cart:{userId}，field = productId，value = quantity */
    public static final String CART_PREFIX = "kfc:cart:";

    /** 餐品详情缓存：kfc:product:{productId} */
    public static final String PRODUCT_PREFIX = "kfc:product:";

    /** 分类+餐品列表缓存（点餐首页） */
    public static final String CATEGORY_LIST = "kfc:category:list";

    /** 登录 token 有效期：2 小时 */
    public static final long TOKEN_TTL_SECONDS = 2 * 60 * 60L;

    /** 餐品详情缓存有效期：10 分钟 */
    public static final long PRODUCT_TTL_SECONDS = 10 * 60L;

    /** 首页分类缓存有效期：5 分钟 */
    public static final long CATEGORY_TTL_SECONDS = 5 * 60L;

    /** 购物车缓存有效期：7 天 */
    public static final long CART_TTL_SECONDS = 7 * 24 * 60 * 60L;
}
