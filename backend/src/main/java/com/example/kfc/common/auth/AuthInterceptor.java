package com.example.kfc.common.auth;

import com.example.kfc.common.constant.RedisKeyConstants;
import com.example.kfc.common.result.Result;
import com.example.kfc.common.result.ResultCode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;
import org.springframework.web.cors.CorsUtils;
import org.springframework.web.servlet.HandlerInterceptor;

import java.nio.charset.StandardCharsets;

/**
 * Token 拦截器
 *
 * <p>规则（顺序有意义）：
 * <ol>
 *   <li>OPTIONS 预检直接放行 —— 浏览器发预检时按规范不带 Authorization，
 *       在这里拦掉会导致所有跨域请求都失败；</li>
 *   <li>Header 里带了 token：先验 JWT 签名与 exp，再查 Redis 会话。
 *       失败时看接口性质：公开只读接口降级为匿名（菜单照常浏览，只是不带会员价），
 *       受保护接口返回 401；</li>
 *   <li>没带 token：公开接口（商品列表/详情、分类、卡档位、登录注册）按匿名放行；
 *       其余一律 401。</li>
 * </ol>
 *
 * <p>放行前把 {@link LoginUser} 放进 {@link UserContext}，Service 层用
 * {@code UserContext.userId()} 就能拿到「当前是谁」，不用业务方法层层传 userId。
 * 请求结束在 {@code afterCompletion} 清理，防止线程复用串号。
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(AuthInterceptor.class);

    private static final AntPathMatcher MATCHER = new AntPathMatcher();

    /** 允许匿名访问的接口（只对这些路径的 GET 生效，写操作仍需登录） */
    private static final String[] PUBLIC_GET = {
            "/api/products",
            "/api/products/**",
            "/api/categories",
            "/api/categories/**",
            "/api/member/plans",
            "/api/member/benefits",
            "/api/member/benefit-rules",
            "/api/ai/health"
    };

    /** 登录 / 注册本身当然不能要求先登录；AI 推荐同理（游客也能问，只是没有会员价） */
    private static final String[] PUBLIC_POST = {
            "/api/users/login",
            "/api/users/register",
            "/api/ai/recommend"
    };

    private final JwtUtil jwtUtil;
    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;
    private final String headerName;
    private final String tokenPrefix;

    public AuthInterceptor(JwtUtil jwtUtil,
                           StringRedisTemplate redis,
                           ObjectMapper objectMapper,
                           @Value("${kfc.auth.header:Authorization}") String headerName,
                           @Value("${kfc.auth.prefix:Bearer }") String tokenPrefix) {
        this.jwtUtil = jwtUtil;
        this.redis = redis;
        this.objectMapper = objectMapper;
        this.headerName = headerName;
        this.tokenPrefix = tokenPrefix;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (CorsUtils.isPreFlightRequest(request)) {
            return true;
        }

        String token = resolveToken(request);
        if (token == null) {
            if (isPublic(request)) {
                return true;
            }
            log.info("拒绝匿名访问：{} {}", request.getMethod(), request.getRequestURI());
            writeUnauthorized(response, "请先登录");
            return false;
        }

        LoginUser fromJwt = jwtUtil.parse(token);
        if (fromJwt == null) {
            /*
             * 签名不对 / 已过期：公开接口不因此报错，直接当匿名访问（菜单该能看还得能看，
             * 只是没有会员价）；受保护接口才返回 401。
             */
            if (isPublic(request)) {
                log.debug("公开接口携带无效 token，按匿名处理：{} {}", request.getMethod(), request.getRequestURI());
                return true;
            }
            writeUnauthorized(response, "登录已过期，请重新登录");
            return false;
        }

        String cached;
        try {
            cached = redis.opsForValue().get(RedisKeyConstants.TOKEN_PREFIX + token);
        } catch (Exception e) {
            log.error("Redis 会话查询失败，按未登录处理", e);
            if (isPublic(request)) {
                return true;
            }
            writeUnauthorized(response, "登录状态校验失败，请稍后重试");
            return false;
        }
        if (cached == null) {
            // 登出、被踢下线、或 Redis 会话先于 JWT 到期
            log.info("token 不在 Redis 会话中：{}", fromJwt.describe());
            if (isPublic(request)) {
                return true;
            }
            writeUnauthorized(response, "登录状态已失效，请重新登录");
            return false;
        }

        UserContext.set(mergeSession(cached, fromJwt));
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                Object handler, Exception ex) {
        UserContext.clear();
    }

    /** Redis 里的会话是最新真相（比如昵称改过），解析失败才退回 JWT 里的信息 */
    private LoginUser mergeSession(String cached, LoginUser fallback) {
        try {
            LoginUser session = objectMapper.readValue(cached, LoginUser.class);
            if (session != null && session.getUserId() != null) {
                return session;
            }
        } catch (Exception e) {
            log.warn("会话 JSON 解析失败，改用 JWT 内容：{}", e.getMessage());
        }
        return fallback;
    }

    /** 支持 "Bearer xxx"，也容忍直接传 token（curl 手工调试时方便） */
    private String resolveToken(HttpServletRequest request) {
        String raw = request.getHeader(headerName);
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String value = raw.trim();
        if (tokenPrefix != null && !tokenPrefix.isBlank()
                && value.regionMatches(true, 0, tokenPrefix, 0, tokenPrefix.length())) {
            value = value.substring(tokenPrefix.length()).trim();
        }
        return value.isEmpty() ? null : value;
    }

    private boolean isPublic(HttpServletRequest request) {
        String method = request.getMethod();
        String path = request.getRequestURI();
        if ("GET".equalsIgnoreCase(method)) {
            for (String pattern : PUBLIC_GET) {
                if (MATCHER.match(pattern, path)) {
                    return true;
                }
            }
        }
        if ("POST".equalsIgnoreCase(method)) {
            for (String pattern : PUBLIC_POST) {
                if (MATCHER.match(pattern, path)) {
                    return true;
                }
            }
        }
        return false;
    }

    private void writeUnauthorized(HttpServletResponse response, String message) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType("application/json;charset=UTF-8");
        try {
            String body = objectMapper.writeValueAsString(
                    Result.fail(ResultCode.UNAUTHORIZED.getCode(), message));
            response.getWriter().write(body);
        } catch (Exception e) {
            log.error("401 响应写出失败", e);
        }
    }
}
