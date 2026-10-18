package com.example.kfc.domain.vo;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * 结算试算出参（GET /api/orders/quote）
 *
 * <p>下单接口用的是同一套算法（OrderServiceImpl#create 内部先 quote 再落库），
 * 所以「结算页看到的金额」和「订单实际金额」不会出现两套算法对不上的情况。
 *
 * <p>金额恒等式：{@code payAmount = goodsAmount + deliveryFee - discountAmount}
 */
@Getter
@Setter
public class OrderQuoteVO {

    private Long userId;

    /** PICKUP / DELIVERY */
    private String pickupType;
    private String pickupTypeText;

    /** 当前购物车明细（带 categoryId，前端可据此标出参与优惠的餐品） */
    private List<CartItemVO> items = new ArrayList<>();

    private Integer itemCount;

    /** 商品金额合计 */
    private BigDecimal goodsAmount;

    /** 外送费（到店自取为 0） */
    private BigDecimal deliveryFee;

    /** 权益优惠合计（商品优惠 + 外送费减免） */
    private BigDecimal discountAmount;

    /** 应付金额 */
    private BigDecimal payAmount;

    /** 是否大神卡持有者 */
    private Boolean godCard;

    /** 命中的卡名，如「季卡」；未持卡为 null */
    private String godCardName;

    /** 命中的优惠明细 */
    private List<DiscountLineVO> discounts = new ArrayList<>();

    /** 优惠汇总文案，如「大神卡已省 ¥14.00」；无优惠为 null */
    private String benefitText;

    /** 未参与优惠的原因提示（未持卡 / 未达门槛 / 不在时段），用于引导开卡 */
    private String hint;
}
