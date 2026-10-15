package com.example.kfc.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * 餐品新增／修改入参
 */
@Getter
@Setter
public class ProductDTO {

    @NotNull(message = "所属分类不能为空")
    private Long categoryId;

    @NotBlank(message = "餐品名不能为空")
    @Size(max = 100, message = "餐品名最长 100 字")
    private String name;

    @Size(max = 500, message = "描述最长 500 字")
    private String description;

    @NotNull(message = "价格不能为空")
    @PositiveOrZero(message = "价格不能为负数")
    private BigDecimal price;

    private String image;

    @PositiveOrZero(message = "库存不能为负数")
    private Integer stock;

    private Integer sortOrder;

    /** 1 上架 0 下架，不传默认上架 */
    private Integer status;
}
