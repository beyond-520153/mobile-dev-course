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

    /** 注册：用户名唯一性校验 + 密码加盐摘要存储 */
    UserVO register(UserRegisterDTO dto);

    /** 登录：校验密码并签发 token（存 Redis，2 小时过期） */
    UserVO login(LoginDTO dto);

    UserVO update(Long id, UserUpdateDTO dto);

    void delete(Long id);

    /** token 是否仍然有效 */
    boolean validateToken(Long userId, String token);
}
