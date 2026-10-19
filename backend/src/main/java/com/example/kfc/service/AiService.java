package com.example.kfc.service;

import com.example.kfc.domain.dto.AiChatDTO;
import com.example.kfc.domain.vo.AiRecommendVO;

import java.util.Map;

/**
 * AI 点餐 —— 业务逻辑层接口
 *
 * <p>职责边界很清楚：<b>模型只做选择与措辞，数据一律来自数据库</b>。
 * 模型返回的商品 id 会逐个回表校验，对不上就用本地规则补位，
 * 所以前端拿到的每一张卡都必然是可下单的真实餐品。
 */
public interface AiService {

    /**
     * 生成一组推荐
     *
     * @param dto 用户的话（可为空）、取餐方式、需要几张卡
     * @return 永远有内容：模型不可用时降级为本地热门推荐，{@code degraded=true}
     */
    AiRecommendVO recommend(AiChatDTO dto);

    /** 自检信息：模型名、是否配了 key、是否在失败冷却期 */
    Map<String, Object> health();
}
