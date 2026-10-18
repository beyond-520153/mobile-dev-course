package com.example.kfc.service.impl;

import com.example.kfc.common.auth.JwtUtil;
import com.example.kfc.common.auth.LoginUser;
import com.example.kfc.common.constant.RedisKeyConstants;
import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.dto.LoginDTO;
import com.example.kfc.domain.dto.UserRegisterDTO;
import com.example.kfc.domain.dto.UserUpdateDTO;
import com.example.kfc.domain.entity.User;
import com.example.kfc.domain.enums.UserRole;
import com.example.kfc.domain.vo.UserVO;
import com.example.kfc.repository.UserRepository;
import com.example.kfc.service.BenefitService;
import com.example.kfc.service.UserService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 用户模块 —— 业务逻辑层实现
 *
 * <p>密码存储：{随机盐}_{SHA-256(盐 + 明文)}，盐按用户随机生成，
 * 明文永不落库。这是课设级别的做法；生产环境应换成 BCrypt/Argon2。
 */
@Service
public class UserServiceImpl implements UserService {

    private static final Logger log = LoggerFactory.getLogger(UserServiceImpl.class);

    private static final String SALT_SEPARATOR = "$";
    private static final int SALT_LENGTH = 16;

    private final UserRepository userRepository;
    private final StringRedisTemplate redis;
    private final BenefitService benefitService;
    private final JwtUtil jwtUtil;
    private final ObjectMapper objectMapper;

    public UserServiceImpl(UserRepository userRepository,
                           StringRedisTemplate redis,
                           BenefitService benefitService,
                           JwtUtil jwtUtil,
                           ObjectMapper objectMapper) {
        this.userRepository = userRepository;
        this.redis = redis;
        this.benefitService = benefitService;
        this.jwtUtil = jwtUtil;
        this.objectMapper = objectMapper;
    }

    @Override
    public List<UserVO> list() {
        return userRepository.findAll().stream().map(UserVO::from).collect(Collectors.toList());
    }

    @Override
    public UserVO getById(Long id) {
        return UserVO.from(getEntity(id));
    }

    @Override
    public UserVO getProfile(Long id) {
        return enrich(UserVO.from(getEntity(id)));
    }

    @Override
    @Transactional
    public UserVO register(UserRegisterDTO dto) {
        if (userRepository.existsByUsername(dto.getUsername())) {
            throw new BusinessException("用户名已被占用：" + dto.getUsername());
        }
        User entity = new User();
        entity.setUsername(dto.getUsername());
        entity.setPassword(encodePassword(dto.getPassword()));
        entity.setPhone(dto.getPhone());
        entity.setNickname(dto.getNickname() == null || dto.getNickname().isBlank()
                ? dto.getUsername() : dto.getNickname());
        entity.setRole(UserRole.CUSTOMER);
        entity.setStatus(1);

        User saved = userRepository.save(entity);
        UserVO vo = enrich(UserVO.from(saved));
        vo.setToken(issueToken(saved));
        return vo;
    }

    @Override
    public UserVO login(LoginDTO dto) {
        User entity = userRepository.findByUsername(dto.getUsername())
                .orElseThrow(() -> new BusinessException("用户名或密码错误"));
        if (!matchesPassword(dto.getPassword(), entity.getPassword())) {
            throw new BusinessException("用户名或密码错误");
        }
        if (!Integer.valueOf(1).equals(entity.getStatus())) {
            throw new BusinessException("账号已被禁用，请联系门店");
        }
        UserVO vo = enrich(UserVO.from(entity));
        vo.setToken(issueToken(entity));
        return vo;
    }

    @Override
    @Transactional
    public UserVO update(Long id, UserUpdateDTO dto) {
        User entity = getEntity(id);
        if (dto.getPhone() != null) {
            entity.setPhone(dto.getPhone());
        }
        if (dto.getNickname() != null) {
            entity.setNickname(dto.getNickname());
        }
        if (dto.getAvatar() != null) {
            entity.setAvatar(dto.getAvatar());
        }
        return enrich(UserVO.from(userRepository.save(entity)));
    }

    /**
     * 给用户出参补上大神卡属性与可享权益
     *
     * <p>「是不是大神卡拥有者」由 t_member_card 当刻的到期时间决定，
     * 不额外在 t_user 上存一个会过期的布尔值 —— 那种冗余字段迟早会不一致。
     */
    private UserVO enrich(UserVO vo) {
        if (vo == null || vo.getId() == null) {
            return vo;
        }
        vo.applyGodCard(benefitService.activeGodCard(vo.getId()),
                benefitService.listBenefits(vo.getId()));
        return vo;
    }

    @Override
    @Transactional
    public void delete(Long id) {
        getEntity(id);
        try {
            userRepository.deleteById(id);
            userRepository.flush();
        } catch (Exception e) {
            throw new BusinessException("该用户已产生订单，无法删除（外键保护）");
        }
    }

    @Override
    public boolean validateToken(Long userId, String token) {
        if (userId == null || token == null || token.isBlank()) {
            return false;
        }
        try {
            String json = redis.opsForValue().get(RedisKeyConstants.TOKEN_PREFIX + token);
            if (json == null) {
                return false;
            }
            LoginUser session = objectMapper.readValue(json, LoginUser.class);
            return session != null && userId.equals(session.getUserId());
        } catch (Exception e) {
            log.warn("Redis 读取 token 失败：{}", e.getMessage());
            return false;
        }
    }

    @Override
    public void logout(String token) {
        if (token == null || token.isBlank()) {
            return;
        }
        try {
            String json = redis.opsForValue().get(RedisKeyConstants.TOKEN_PREFIX + token);
            if (json != null) {
                LoginUser session = objectMapper.readValue(json, LoginUser.class);
                if (session != null && session.getUserId() != null) {
                    redis.delete(RedisKeyConstants.USER_TOKEN_PREFIX + session.getUserId());
                }
            }
            redis.delete(RedisKeyConstants.TOKEN_PREFIX + token);
            log.info("登出成功，token 已从 Redis 移除");
        } catch (Exception e) {
            // 登出失败不报错给前端：本地 token 已经丢了，再报错只会让用户卡住
            log.warn("登出清理 Redis 会话失败：{}", e.getMessage());
        }
    }

    /**
     * 签发 JWT 并建立 Redis 会话
     *
     * <p>两者必须同时成功：JWT 是「你是谁」的自证，Redis 是「这个身份还有效」的服务端凭据。
     * Redis 写失败时宁可让登录失败，也不能返回一个之后必然 401 的 token
     * —— 那种「登录成功了但点什么都说未登录」的体验比直接失败更难查。
     */
    private String issueToken(User user) {
        boolean godCard = false;
        try {
            godCard = benefitService.isGodCardOwner(user.getId());
        } catch (Exception e) {
            log.warn("签发 token 时查询大神卡状态失败（按非会员处理）：{}", e.getMessage());
        }

        LoginUser loginUser = LoginUser.of(user, godCard);
        String token = jwtUtil.generate(loginUser);
        long ttl = jwtUtil.getTtlSeconds() > 0
                ? jwtUtil.getTtlSeconds() : RedisKeyConstants.TOKEN_TTL_SECONDS;
        try {
            String json = objectMapper.writeValueAsString(loginUser);
            redis.opsForValue().set(RedisKeyConstants.TOKEN_PREFIX + token, json,
                    Duration.ofSeconds(ttl));
            redis.opsForValue().set(RedisKeyConstants.USER_TOKEN_PREFIX + user.getId(), token,
                    Duration.ofSeconds(ttl));
        } catch (Exception e) {
            log.error("Redis 写入登录会话失败", e);
            throw new BusinessException("登录服务暂时不可用，请稍后重试");
        }
        log.info("登录成功：{}，会话有效期 {} 秒", loginUser.describe(), ttl);
        return token;
    }

    private User getEntity(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new BusinessException("用户不存在：" + id));
    }

    private static String encodePassword(String raw) {
        String salt = UUID.randomUUID().toString().replace("-", "").substring(0, SALT_LENGTH);
        return salt + SALT_SEPARATOR + sha256(salt + raw);
    }

    private static boolean matchesPassword(String raw, String stored) {
        if (stored == null || !stored.contains(SALT_SEPARATOR)) {
            return false;
        }
        int index = stored.indexOf(SALT_SEPARATOR);
        String salt = stored.substring(0, index);
        String hash = stored.substring(index + 1);
        return hash.equalsIgnoreCase(sha256(salt + raw));
    }

    private static String sha256(String text) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(text.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("当前 JVM 不支持 SHA-256", e);
        }
    }
}
