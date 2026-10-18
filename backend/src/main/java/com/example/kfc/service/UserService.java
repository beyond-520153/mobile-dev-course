package com.example.kfc.service;

import com.example.kfc.domain.dto.LoginDTO;
import com.example.kfc.domain.dto.UserRegisterDTO;
import com.example.kfc.domain.dto.UserUpdateDTO;
import com.example.kfc.domain.vo.UserVO;

import java.util.List;

/**
 * 用户模块 —— 业务逻辑层 Service 接口
 */
public interface UserService {

    List<UserVO> list();

    UserVO getById(Long id);

    /**
     * 用户详情（带大神卡属性与可享权益）
     *
     * <p>与 getById 分开：getById 被订单等服务在高频路径上调用，
     * 不该每次都去查卡和权益；只有前端要展示的详情才走这里。
     */
    UserVO getProfile(Long id);

    /** 注册：用户名唯一性校验 + 密码加盐摘要存储 */
    UserVO register(UserRegisterDTO dto);

    /** 登录：校验密码哈希并签发 JWT（会话同时写入 Redis，1 小时过期） */
    UserVO login(LoginDTO dto);

    /** 登出：删除该 token 对应的 Redis 会话（JWT 自身无法撤销，靠这一步失效） */
    void logout(String token);

    UserVO update(Long id, UserUpdateDTO dto);

    void delete(Long id);

    /** token 是否仍然有效 */
    boolean validateToken(Long userId, String token);
}
