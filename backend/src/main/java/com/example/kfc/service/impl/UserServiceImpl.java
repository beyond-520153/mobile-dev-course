package com.example.kfc.service.impl;

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

    public UserServiceImpl(UserRepository userRepository,
                           StringRedisTemplate redis,
                           BenefitService benefitService) {
        this.userRepository = userRepository;
        this.redis = redis;
        this.benefitService = benefitService;
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
        vo.setToken(issueToken(saved.getId()));
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
        vo.setToken(issueToken(entity.getId()));
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
        if (userId == null || token == null) {
            return false;
        }
        try {
            String saved = redis.opsForValue().get(RedisKeyConstants.TOKEN_PREFIX + userId);
            return token.equals(saved);
        } catch (Exception e) {
            log.warn("Redis 读取 token 失败：{}", e.getMessage());
            return false;
        }
    }

    /** 签发 token 并写入 Redis（2 小时过期） */
    private String issueToken(Long userId) {
        String token = UUID.randomUUID().toString().replace("-", "");
        try {
            redis.opsForValue().set(RedisKeyConstants.TOKEN_PREFIX + userId, token,
                    Duration.ofSeconds(RedisKeyConstants.TOKEN_TTL_SECONDS));
        } catch (Exception e) {
            log.warn("Redis 写入 token 失败：{}", e.getMessage());
        }
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
