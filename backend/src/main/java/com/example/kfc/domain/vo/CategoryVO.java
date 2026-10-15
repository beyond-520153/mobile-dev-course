package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.Category;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

/**
 * 分类出参
 *
 * <p>点餐首页需要「左侧分类 + 右侧餐品列表」一次性拿到，
 * 所以这里把该分类下的餐品一起装进去，避免前端发 N 次请求。
 */
@Getter
@Setter
public class CategoryVO {

    private Long id;
    private String name;
    private Integer sortOrder;
    private String icon;
    private Integer status;

    /** 该分类下的在售餐品 */
    private List<ProductVO> products = new ArrayList<>();

    public static CategoryVO from(Category c) {
        if (c == null) {
            return null;
        }
        CategoryVO vo = new CategoryVO();
        vo.setId(c.getId());
        vo.setName(c.getName());
        vo.setSortOrder(c.getSortOrder());
        vo.setIcon(c.getIcon());
        vo.setStatus(c.getStatus());
        return vo;
    }
}
