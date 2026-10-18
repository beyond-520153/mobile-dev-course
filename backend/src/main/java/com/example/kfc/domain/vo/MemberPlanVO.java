package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.MemberPlan;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * 会员卡档位出参（大神卡页的三张价格卡）
 */
@Getter
@Setter
public class MemberPlanVO {

    private Long id;
    private String code;
    private String cardType;
    private String name;
    private Integer months;

    private BigDecimal price;
    private BigDecimal originPrice;
    private Integer privilegeNum;

    /** 有效天数，前端价格卡底下那行文案 */
    private Integer days;

    public static MemberPlanVO from(MemberPlan p) {
        if (p == null) {
            return null;
        }
        MemberPlanVO vo = new MemberPlanVO();
        vo.setId(p.getId());
        vo.setCode(p.getCode());
        vo.setCardType(p.getCardType());
        vo.setName(p.getName());
        vo.setMonths(p.getMonths());
        vo.setPrice(p.getPrice());
        vo.setOriginPrice(p.getOriginPrice());
        vo.setPrivilegeNum(p.getPrivilegeNum());
        // 天数按真实日历算（年卡 365、季卡 90/91、月卡 28~31），不写死 months * 30
        if (p.getMonths() == null || p.getMonths() <= 0) {
            vo.setDays(0);
        } else {
            java.time.OffsetDateTime now = java.time.OffsetDateTime.now();
            vo.setDays((int) java.time.temporal.ChronoUnit.DAYS.between(now, now.plusMonths(p.getMonths())));
        }
        return vo;
    }
}
