package com.example.kfc.domain.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/**
 * 下单入参
 *
 * <p>下单的餐品来源是「该用户当前的购物车」，不在此处传明细，
 * 避免前端算价与服务端算价不一致。
 */
@Getter
@Setter
public class OrderCreateDTO {

    @NotNull(message = "用户不能为空")
    private Long userId;

    /** 外送时必填；到店自取传 null */
    private Long addressId;

    /** PICKUP 到店自取（默认） / DELIVERY 外送 */
    private String pickupType;

    @Size(max = 255, message = "备注最长 255 字")
    private String remark;
}
