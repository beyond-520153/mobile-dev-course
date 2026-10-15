package com.example.kfc.domain.dto;

import com.example.kfc.domain.enums.OrderStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

/**
 * 修改订单状态入参（店员侧流转用）
 */
@Getter
@Setter
public class OrderUpdateDTO {

    @NotNull(message = "订单状态不能为空")
    private OrderStatus status;

    private String remark;
}
