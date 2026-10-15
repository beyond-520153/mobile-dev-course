package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.User;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.Setter;

import java.time.OffsetDateTime;

/**
 * 用户出参
 *
 * <p>刻意不含 password 字段：实体永远不会被直接序列化返回给客户端。
 */
@Getter
@Setter
public class UserVO {

    private Long id;
    private String username;
    private String phone;
    private String nickname;
    private String avatar;
    private String role;
    private Integer status;

    /** 统一按东八区、秒级精度输出，理由见 OrderVO */
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime createdAt;

    /** 仅在登录／注册成功时返回，其它接口为 null */
    private String token;

    public static UserVO from(User u) {
        if (u == null) {
            return null;
        }
        UserVO vo = new UserVO();
        vo.setId(u.getId());
        vo.setUsername(u.getUsername());
        vo.setPhone(u.getPhone());
        vo.setNickname(u.getNickname());
        vo.setAvatar(u.getAvatar());
        vo.setStatus(u.getStatus());
        vo.setCreatedAt(u.getCreatedAt());
        if (u.getRole() != null) {
            vo.setRole(u.getRole().name());
        }
        return vo;
    }
}
