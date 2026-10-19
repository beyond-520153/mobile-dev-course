package com.example.kfc.domain.vo;

import lombok.Getter;
import lombok.Setter;

/**
 * AI 推荐卡片顶部的门店信息（截图里「农林大学餐厅 + 定位圈 + 地址 + 581m」这一行）
 */
@Getter
@Setter
public class AiStoreVO {

    private String name;

    private String address;

    /** 距离文案，如「581m」 */
    private String distance;

    /** 取餐方式：PICKUP / DELIVERY / DRIVE */
    private String pickupType;

    /** 取餐方式中文，如「自取」。前端气泡里用 */
    private String pickupText;
}
