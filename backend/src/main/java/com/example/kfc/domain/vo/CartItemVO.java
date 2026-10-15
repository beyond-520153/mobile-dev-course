package com.example.kfc.domain.vo;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * 购物车条目出参
 *
 * <p>带上了餐品名／图／单价，前端渲染购物车列表时不用再查商品接口。
 */
@Getter
@Setter
public class CartItemVO {

    /** 购物车条目主键（改数量、删条目用这个 id） */
    private Long id;

    private Long userId;
    private Long productId;

    private String productName;
    private String productImage;
    private BigDecimal price;
    private Integer quantity;

    /** price * quantity，服务端算好，避免前端浮点误差 */
    private BigDecimal subtotal;

    /** 餐品当前库存，前端据此置灰「+」 */
    private Integer stock;

    /** 餐品是否上架 */
    private Integer productStatus;
}
