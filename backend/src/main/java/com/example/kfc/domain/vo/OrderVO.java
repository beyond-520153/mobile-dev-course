package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.Order;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 订单出参（订单主信息 + 明细列表）
 */
@Getter
@Setter
public class OrderVO {

    private Long id;
    private String orderNo;
    private Long userId;
    private Long addressId;

    /** PICKUP / DELIVERY */
    private String pickupType;
    /** 取餐方式中文，前端直接展示 */
    private String pickupTypeText;

    /** 商品总额 */
    private BigDecimal totalAmount;
    /** 外送费（到店自取为 0） */
    private BigDecimal deliveryFee;
    /** 会员卡权益优惠合计 */
    private BigDecimal discountAmount;
    /** 实付金额 = totalAmount + deliveryFee - discountAmount */
    private BigDecimal payAmount;

    /** 优惠文案，如「每日 1 杯咖啡 10 元 -9.00（拿铁 ×1）；外送费已免 -9.00」 */
    private String benefitDetail;

    /** 状态码，如 PENDING_PAYMENT */
    private String status;
    /** 状态中文，如「待支付」 */
    private String statusText;

    private String remark;
    private String pickupCode;

    /**
     * 统一按东八区、秒级精度输出。
     *
     * <p>不这么写的话：刚下单时是「内存里的 OffsetDateTime」带本地偏移和纳秒精度
     * （2026-10-15T21:10:54.1842932+08:00），从库里读回来却是 UTC 微秒精度
     * （2026-10-15T13:10:54.184293Z）——同一个字段两种格式，前端解析容易踩坑。
     */
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime payTime;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime createdAt;

    /** 明细件数（各条目 quantity 之和） */
    private Integer itemCount;

    private List<OrderItemVO> items = new ArrayList<>();

    public static OrderVO from(Order o) {
        if (o == null) {
            return null;
        }
        OrderVO vo = new OrderVO();
        vo.setId(o.getId());
        vo.setOrderNo(o.getOrderNo());
        vo.setUserId(o.getUserId());
        vo.setAddressId(o.getAddressId());
        vo.setPickupType(o.getPickupType());
        vo.setPickupTypeText("DELIVERY".equals(o.getPickupType()) ? "外送" : "到店自取");
        vo.setTotalAmount(o.getTotalAmount());
        vo.setDeliveryFee(o.getDeliveryFee());
        vo.setDiscountAmount(o.getDiscountAmount());
        vo.setPayAmount(o.getPayAmount());
        vo.setBenefitDetail(o.getBenefitDetail());
        vo.setRemark(o.getRemark());
        vo.setPickupCode(o.getPickupCode());
        vo.setPayTime(o.getPayTime());
        vo.setCreatedAt(o.getCreatedAt());
        if (o.getStatus() != null) {
            vo.setStatus(o.getStatus().name());
            vo.setStatusText(o.getStatus().getText());
        }
        return vo;
    }
}
