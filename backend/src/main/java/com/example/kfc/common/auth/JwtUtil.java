package com.example.kfc.common.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 签发 / 校验
 *
 * <p>用 HS256（对称签名）：本项目只有后端一家在签发和校验，
 * 对称密钥足够，也不需要额外维护公私钥。密钥从 {@code kfc.auth.secret} 注入，
 * 长度不足 32 字节时 jjwt 会直接抛 {@code WeakKeyException} —— 这是好事，
 * 说明它拒绝用短密钥签名，别去 try-catch 掉。
 *
 * <p>JWT 与 Redis 会话是「双因子」关系：
 * <ul>
 *   <li>JWT 防伪造（签名对不上直接拒绝，不用查库）；</li>
 *   <li>Redis 防「已登出还拿着旧 token 用」（登出即删 key，签名依然有效也没用）。</li>
 * </ul>
 * 所以两者缺一不可，不能只验其中一边。
 */
@Component
public class JwtUtil {

    private static final Logger log = LoggerFactory.getLogger(JwtUtil.class);

    private static final String CLAIM_USERNAME = "username";
    private static final String CLAIM_NICKNAME = "nickname";
    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_GOD_CARD = "god";

    private final SecretKey key;
    private final long ttlSeconds;

    public JwtUtil(@Value("${kfc.auth.secret}") String secret,
                   @Value("${kfc.auth.ttl-minutes:60}") long ttlMinutes) {
        byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException(
                    "kfc.auth.secret 至少需要 32 字节（256 位），当前 " + bytes.length + " 字节");
        }
        this.key = Keys.hmacShaKeyFor(bytes);
        this.ttlSeconds = ttlMinutes * 60L;
    }

    /** 会话有效期（秒），Redis 与 JWT 共用同一个值 */
    public long getTtlSeconds() {
        return ttlSeconds;
    }

    /** 签发 token：subject 放 userId，其余基础信息放自定义 claim */
    public String generate(LoginUser loginUser) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(String.valueOf(loginUser.getUserId()))
                .claim(CLAIM_USERNAME, loginUser.getUsername())
                .claim(CLAIM_NICKNAME, loginUser.getNickname())
                .claim(CLAIM_ROLE, loginUser.getRole())
                .claim(CLAIM_GOD_CARD, Boolean.TRUE.equals(loginUser.getGodCard()))
                .issuedAt(new Date(now))
                .expiration(new Date(now + ttlSeconds * 1000L))
                .signWith(key)
                .compact();
    }

    /**
     * 校验签名与有效期并取回用户信息
     *
     * @return 解析成功返回 LoginUser；签名错误、格式错误、已过期一律返回 null
     */
    public LoginUser parse(String token) {
        if (token == null || token.isBlank()) {
            return null;
        }
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            Long userId = Long.valueOf(claims.getSubject());
            LoginUser loginUser = new LoginUser();
            loginUser.setUserId(userId);
            loginUser.setUsername(claims.get(CLAIM_USERNAME, String.class));
            loginUser.setNickname(claims.get(CLAIM_NICKNAME, String.class));
            loginUser.setRole(claims.get(CLAIM_ROLE, String.class));
            loginUser.setGodCard(claims.get(CLAIM_GOD_CARD, Boolean.class));
            loginUser.setLoginAt(claims.getIssuedAt() == null ? null : claims.getIssuedAt().getTime());
            return loginUser;
        } catch (JwtException | IllegalArgumentException e) {
            // 过期也是 JwtException（ExpiredJwtException），统一按未登录处理
            log.debug("JWT 校验失败：{}", e.getMessage());
            return null;
        }
    }
}
