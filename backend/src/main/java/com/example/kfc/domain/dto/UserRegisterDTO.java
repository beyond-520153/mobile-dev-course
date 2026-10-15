package com.example.kfc.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/**
 * 注册入参
 */
@Getter
@Setter
public class UserRegisterDTO {

    @NotBlank(message = "用户名不能为空")
    @Size(min = 3, max = 50, message = "用户名长度 3~50 位")
    private String username;

    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 50, message = "密码长度 6~50 位")
    private String password;

    @Size(max = 20, message = "手机号最长 20 位")
    private String phone;

    @Size(max = 50, message = "昵称最长 50 字")
    private String nickname;
}
