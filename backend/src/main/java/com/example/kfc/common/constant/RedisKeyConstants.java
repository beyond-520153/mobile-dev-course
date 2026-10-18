package com.example.kfc.common.constant;

/**
 * Redis key 统一在这里定义，避免各处硬拼字符串
 *
 * <p>命名规范：kfc:{业务}:{标识}
 */
public final class RedisKeyConstants {

    private RedisKeyConstants() {
    }

    /**
     * 登录会话：kfc:token:{token}
     *
     * <p>注意 key 是 token 本身（不是 userId）—— 拦截器拿到 token 直接 GET 即可，
     * 不用先解析出 userId 再查，少一次依赖；value 是 {@code LoginUser} 的 JSON，
     * 含 userId / username / nickname / role 等基础信息。
     */
    public static final String TOKEN_PREFIX = "kfc:token:";

    /**
     * 用户当前 token 索引：kfc:token:user:{userId}
     *
     * <p>用于「登出全部设备」「判断某人是否在线」，以及按用户维度清理会话。
     */
    public static final String USER_TOKEN_PREFIX = "kfc:token:user:";

    /** 购物车 Hash：kfc:cart:{userId}，field = productId，value = quantity */
    public static final String CART_PREFIX = "kfc:cart:";

    /** 餐品详情缓存：kfc:product:{productId} */
    public static final String PRODUCT_PREFIX = "kfc:product:";

    /** 分类+餐品列表缓存（点餐首页） */
    public static final String CATEGORY_LIST = "kfc:category:list";

    /** 会员概要缓存：kfc:member:summary:{userId} */
    public static final String MEMBER_SUMMARY_PREFIX = "kfc:member:summary:";

    /** 会员概要缓存有效期：60 秒（开卡 / 累计 V金 会主动失效，这里只是兜底） */
    public static final long MEMBER_SUMMARY_TTL_SECONDS = 60L;

    /**
     * 登录会话默认有效期：1 小时
     *
     * <p>真正生效的是 {@code kfc.auth.ttl-minutes}，这里只是兜底默认值，
     * 改配置即可，不用改代码。
     */
    public static final long TOKEN_TTL_SECONDS = 60 * 60L;

    /** 餐品详情缓存有效期：10 分钟 */
    public static final long PRODUCT_TTL_SECONDS = 10 * 60L;

    /** 首页分类缓存有效期：5 分钟 */
    public static final long CATEGORY_TTL_SECONDS = 5 * 60L;

    /** 购物车缓存有效期：7 天 */
    public static final long CART_TTL_SECONDS = 7 * 24 * 60 * 60L;
}
