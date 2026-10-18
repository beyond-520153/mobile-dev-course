package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.Product;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * 餐品出参
 */
@Getter
@Setter
public class ProductVO {

    private Long id;
    private Long categoryId;
    private String name;
    private String description;
    private BigDecimal price;
    private BigDecimal originPrice;
    private String image;
    private Integer stock;
    private Integer sortOrder;
    private Integer status;

    /* ------------------------------------------------------------------
     * 会员价：这三个字段不属于餐品本身，而是「当前登录用户看到的差异」。
     * 未登录 / 未持卡时全部为 null，前端据此决定是否渲染会员价标签。
     * 注意不要把它们写进 Redis 餐品缓存 —— 缓存是所有人共用的，写进去会串号。
     * ------------------------------------------------------------------ */

    /** 单件可享的会员价（取最优规则），null 表示无 */
    private BigDecimal memberPrice;

    /** 提供该价格的卡名，如「大神卡」「咖啡卡」 */
    private String memberCardName;

    /** 规则名，如「每日 1 杯指定咖啡 10 元」，用于标签下方的说明 */
    private String memberBenefit;

    /** 拼好的展示文案，如「大神卡 ¥10.00」，前端直接显示即可 */
    private String memberPriceText;

    public static ProductVO from(Product p) {
        if (p == null) {
            return null;
        }
        ProductVO vo = new ProductVO();
        vo.setId(p.getId());
        vo.setCategoryId(p.getCategoryId());
        vo.setName(p.getName());
        vo.setDescription(p.getDescription());
        vo.setPrice(p.getPrice());
        vo.setOriginPrice(p.getOriginPrice());
        vo.setImage(p.getImage());
        vo.setStock(p.getStock());
        vo.setSortOrder(p.getSortOrder());
        vo.setStatus(p.getStatus());
        return vo;
    }
}
