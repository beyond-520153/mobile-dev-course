package com.example.kfc.domain.dto;

import lombok.Getter;
import lombok.Setter;

import java.util.List;

/**
 * AI 点餐入参
 *
 * <p>一个接口同时承担三种语义：
 * <ul>
 *   <li>{@code message} 为空 —— 首屏，让模型给一组默认推荐（对应截图里进门那一屏）；</li>
 *   <li>{@code message} 为「换一换」—— 同一组默认推荐的换一批；</li>
 *   <li>{@code message} 为自然语言（「来点辣的」「30 元以内」）—— 带偏好重算。</li>
 * </ul>
 *
 * <p>会话不入库：{@code history} 由前端带着走，后端只做校验和截断。
 * 这样「来点辣的」→「再加个喝的」这类追问能接上，又不用多一张会话表和过期清理。
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
     * 前几轮对话，让模型知道刚才聊到哪儿了。
     *
     * <p>role 只认 user / assistant（其它一律丢弃，防止前端伪造 system 指令），
     * 后端最多取最近 6 条、每条 120 字。
     */
    private List<ChatTurn> history;

    /**
     * 用户 ID，仅在匿名调用（没带 token）时由前端显式传。
     *
     * <p>带了有效 token 时以拦截器解析出来的身份为准，这个字段会被忽略 ——
     * 否则任何人都能拿别人的 ID 去套会员价。
     */
    private Long userId;

    /** 一轮对话：谁说的 + 说了什么 */
    @Getter
    @Setter
    public static class ChatTurn {

        /** user 或 assistant */
        private String role;

        private String text;
    }
}
