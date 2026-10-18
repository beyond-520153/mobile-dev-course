package com.example.kfc.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

/**
 * 开通会员卡请求体
 */
@Getter
@Setter
public class MemberOpenDTO {

    @NotNull(message = "用户 id 不能为空")
    private Long userId;

    /** 档位编码：GOD_MONTH / GOD_SEASON / GOD_YEAR / COFFEE_30 */
    @NotBlank(message = "请选择套餐")
    private String planCode;
}
