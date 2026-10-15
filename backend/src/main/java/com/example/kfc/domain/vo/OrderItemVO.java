package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.OrderItem;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * 订单明细出参
 */
@Getter
@Setter
public class OrderItemVO {

    private Long id;
    private Long orderId;
    private Long productId;
    private String productName;
    private String productImage;
    private BigDecimal price;
    private Integer quantity;
    private BigDecimal subtotal;

    public static OrderItemVO from(OrderItem i) {
        if (i == null) {
            return null;
        }
        OrderItemVO vo = new OrderItemVO();
        vo.setId(i.getId());
        vo.setOrderId(i.getOrderId());
        vo.setProductId(i.getProductId());
        vo.setProductName(i.getProductName());
        vo.setProductImage(i.getProductImage());
        vo.setPrice(i.getPrice());
        vo.setQuantity(i.getQuantity());
        vo.setSubtotal(i.getSubtotal());
        return vo;
    }
}
