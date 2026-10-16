package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.Product;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * 餐品出参
 */
@Getter
@Setter
public class ProductVO {

    private Long id;
    private Long categoryId;
    private String name;
    private String description;
    private BigDecimal price;
    private BigDecimal originPrice;
    private String image;
    private Integer stock;
    private Integer sortOrder;
    private Integer status;

    public static ProductVO from(Product p) {
        if (p == null) {
            return null;
        }
        ProductVO vo = new ProductVO();
        vo.setId(p.getId());
        vo.setCategoryId(p.getCategoryId());
        vo.setName(p.getName());
        vo.setDescription(p.getDescription());
        vo.setPrice(p.getPrice());
        vo.setOriginPrice(p.getOriginPrice());
        vo.setImage(p.getImage());
        vo.setStock(p.getStock());
        vo.setSortOrder(p.getSortOrder());
        vo.setStatus(p.getStatus());
        return vo;
    }
}
