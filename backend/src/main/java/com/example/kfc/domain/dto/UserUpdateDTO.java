package com.example.kfc.domain.dto;

import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/**
 * 修改用户资料入参（用户名与密码不走这里）
 */
@Getter
@Setter
public class UserUpdateDTO {

    @Size(max = 20, message = "手机号最长 20 位")
    private String phone;

    @Size(max = 50, message = "昵称最长 50 字")
    private String nickname;

    private String avatar;
}
