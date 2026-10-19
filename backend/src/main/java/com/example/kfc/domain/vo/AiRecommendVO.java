package com.example.kfc.domain.vo;

import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

/**
 * AI 点餐一次推荐的完整出参
 *
 * <p>思路是「模型只负责挑哪几样、说一句人话」，其余全部由后端用真实菜单补齐：
 * 图片、价格、库存、会员价都来自数据库，模型碰不到，所以不会出现
 * 「AI 推荐了一个不存在的餐品」或者「价格对不上」这类问题。
 */
@Getter
@Setter
public class AiRecommendVO {

    /** 模型说的一句回复（已裁到 45 字内），前端放在第二个气泡里 */
    private String reply;

    /**
     * 是否降级：true 表示模型这次没调通 / 超时 / 给了非法 id，
     * 卡片是本地按分类热度补的。前端可以照常展示，也可以加一行「AI 繁忙」提示。
     */
    private Boolean degraded;

    /** 降级原因，正常时为 null */
    private String degradeReason;

    /** 门店信息 */
    private AiStoreVO store;

    /** 推荐卡片，默认 6 张，index 从 1 开始连续 */
    private List<AiPickVO> items = new ArrayList<>();

    /** 本次用的模型名，便于排查 */
    private String model;

    /** 模型耗时（毫秒），正常为 0 */
    private Long costMs;
}
