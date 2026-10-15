package com.example.kfc.common.constant;

/**
 * Redis key 统一在这里定义，避免各处拼字符串
 */
public final class RedisKeyConstants {

    private RedisKeyConstants() {
    }

    /** 登录 token：kfc:token:{userId} */
    public static final String TOKEN_PREFIX = "kfc:token:";

    /** 购物车：kfc:cart:{userId} */
    public static final String CART_PREFIX = "kfc:cart:";

    /** 餐品缓存：kfc:product:{productId} */
    public static final String PRODUCT_PREFIX = "kfc:product:";

    /** 餐品分类缓存 */
    public static final String CATEGORY_LIST = "kfc:category:list";

    // TODO 按业务继续补充
}
