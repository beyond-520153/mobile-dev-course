package com.example.kfc.common.cache;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * Redis 的 JSON 缓存小工具
 *
 * <p>统一做三件事：① 把对象转成不带类型标记的纯 JSON 存进去；
 * ② 读失败／Redis 不可用时返回 null 让调用方回退数据库，绝不因为缓存挂了业务就挂；
 * ③ 把异常都收敛在这里，Service 里不用到处写 try-catch。
 */
@Component
public class RedisJsonCache {

    private static final Logger log = LoggerFactory.getLogger(RedisJsonCache.class);

    private final StringRedisTemplate redis;
    private final ObjectMapper json;

    public RedisJsonCache(StringRedisTemplate redis, ObjectMapper json) {
        this.redis = redis;
        this.json = json;
    }

    /** 命中返回对象；未命中或 Redis 不可用返回 null */
    public <T> T get(String key, TypeReference<T> type) {
        try {
            String text = redis.opsForValue().get(key);
            if (text == null || text.isEmpty()) {
                return null;
            }
            return json.readValue(text, type);
        } catch (Exception e) {
            log.warn("Redis 读取失败，回退数据库。key={}，原因={}", key, e.getMessage());
            return null;
        }
    }

    /** 写入缓存并设置过期时间（秒） */
    public void put(String key, Object value, long ttlSeconds) {
        try {
            redis.opsForValue().set(key, json.writeValueAsString(value), Duration.ofSeconds(ttlSeconds));
        } catch (Exception e) {
            log.warn("Redis 写入失败，跳过缓存。key={}，原因={}", key, e.getMessage());
        }
    }

    /** 删除缓存（数据变更后调用） */
    public void evict(String key) {
        try {
            redis.delete(key);
        } catch (Exception e) {
            log.warn("Redis 删除失败。key={}，原因={}", key, e.getMessage());
        }
    }
}
