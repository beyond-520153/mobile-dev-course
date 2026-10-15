package com.example.kfc.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/**
 * 收货地址新增／修改入参
 */
@Getter
@Setter
public class AddressDTO {

    @NotNull(message = "用户不能为空")
    private Long userId;

    @NotBlank(message = "收货人不能为空")
    @Size(max = 50, message = "收货人最长 50 字")
    private String receiver;

    @NotBlank(message = "手机号不能为空")
    @Size(max = 20, message = "手机号最长 20 位")
    private String phone;

    private String province;

    private String city;

    private String district;

    @NotBlank(message = "详细地址不能为空")
    @Size(max = 255, message = "详细地址最长 255 字")
    private String detail;

    private Boolean isDefault;
}
