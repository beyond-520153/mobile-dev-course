package com.example.kfc.domain.dto;

import lombok.Getter;
import lombok.Setter;

/**
 * AI 点餐入参
 *
 * <p>一个接口同时承担三种语义：
 * <ul>
 *   <li>{@code message} 为空 —— 首屏，让模型给一组默认推荐（对应截图里进门那一屏）；</li>
 *   <li>{@code message} 为「换一换」—— 同一组默认推荐的换一批；</li>
 *   <li>{@code message} 为自然语言（「来点辣的」「30 元以内」「选1和2」）—— 带偏好重算。</li>
 * </ul>
 * 不做多轮会话保存：推荐是无状态的，每次按当前这句话重算即可，
 * 省掉一张会话表和一堆过期清理逻辑。
 */
@Getter
@Setter
public class AiChatDTO {

    /**
     * 用户说的话，可为空。
     *
     * <p>裁剪到 200 字：这段文本会直接进 prompt，过长既烧 token 又能被用来做提示注入。
     */
    private String message;

    /** 取餐方式：PICKUP / DELIVERY / DRIVE，只影响话术，不影响推荐结果 */
    private String pickupType;

    /** 要几张卡片，默认 6（截图是 3×2 六宫格），上限 9 */
    private Integer count;

    /**
     * 用户 ID，仅在匿名调用（没带 token）时由前端显式传。
     *
     * <p>带了有效 token 时以拦截器解析出来的身份为准，这个字段会被忽略 ——
     * 否则任何人都能拿别人的 ID 去套会员价。
     */
    private Long userId;
}
