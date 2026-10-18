package com.example.kfc.common.auth;

/**
 * 当前请求的登录用户 —— ThreadLocal 持有
 *
 * <p>拦截器在 {@code preHandle} 写入、{@code afterCompletion} 必须清理。
 * Tomcat 的线程是复用的，不清理会把上一个请求的用户带到下一个请求上，
 * 表现为「匿名请求莫名拿到了别人的会员价」这种极难排查的串号问题。
 */
public final class UserContext {

    private static final ThreadLocal<LoginUser> HOLDER = new ThreadLocal<>();

    private UserContext() {
    }

    public static void set(LoginUser loginUser) {
        HOLDER.set(loginUser);
    }

    public static LoginUser get() {
        return HOLDER.get();
    }

    /** 当前用户 ID，未登录返回 null（商品接口据此决定是否展示会员价） */
    public static Long userId() {
        LoginUser loginUser = HOLDER.get();
        return loginUser == null ? null : loginUser.getUserId();
    }

    public static boolean isLogin() {
        return userId() != null;
    }

    public static void clear() {
        HOLDER.remove();
    }
}
