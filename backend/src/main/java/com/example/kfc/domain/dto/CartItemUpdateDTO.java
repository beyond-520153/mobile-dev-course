package com.example.kfc.domain.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

/**
 * 修改购物车条目数量入参
 *
 * <p>数量传 0 表示删除该条目。
 */
@Getter
@Setter
public class CartItemUpdateDTO {

    @NotNull(message = "数量不能为空")
    @Min(value = 0, message = "数量不能为负数")
    private Integer quantity;
}
