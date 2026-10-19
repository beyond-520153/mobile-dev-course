package com.example.kfc.domain.vo;

import lombok.Getter;
import lombok.Setter;

/**
 * AI 推荐的一张餐品卡
 *
 * <p>字段与截图里的卡片一一对应：左上角「选N」贴纸、商品图、名称、现价+划线原价。
 * reason 是模型给的一句话卖点，前端放在卡片底部一行小字（可省略）。
 */
@Getter
@Setter
public class AiPickVO {

    /** 序号，从 1 开始 —— 对应截图里的「选1」「选2」，用户可以直接说「选1和3」 */
    private Integer index;

    /** 贴纸文案，如「选1」 */
    private String label;

    /** 餐品本体，会员价字段按当前登录用户填好了 */
    private ProductVO product;

    /** 推荐理由，≤ 14 字 */
    private String reason;

    /** 数据来源：AI=模型选的，FALLBACK=模型不可用/给错 id 时本地补位 */
    private String source;
}
