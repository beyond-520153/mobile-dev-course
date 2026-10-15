package com.example.kfc.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/**
 * 分类新增／修改入参
 */
@Getter
@Setter
public class CategoryDTO {

    @NotBlank(message = "分类名不能为空")
    @Size(max = 50, message = "分类名最长 50 字")
    private String name;

    private Integer sortOrder;

    private String icon;

    private Integer status;
}
