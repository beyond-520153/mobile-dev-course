package com.example.kfc.domain.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

/**
 * 加入购物车入参
 *
 * <p>同一用户重复加同一餐品时，Service 做数量累加，不新增行。
 */
@Getter
@Setter
public class CartItemDTO {

    @NotNull(message = "用户不能为空")
    private Long userId;

    @NotNull(message = "餐品不能为空")
    private Long productId;

    @NotNull(message = "数量不能为空")
    @Min(value = 1, message = "数量至少为 1")
    private Integer quantity;
}
