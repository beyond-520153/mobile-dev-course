package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.Member;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * 会员账户出参（WOW 会员中心顶部的四格数据 + 昵称 + 会员号）
 */
@Getter
@Setter
public class MemberSummaryVO {

    private Long id;
    private Long userId;
    private String memberNo;
    private String nickname;

    /** 普通会员 / WOW会员：持有任意有效卡即为 WOW会员 */
    private String level;

    private Integer vgold;
    private Integer couponCount;
    private BigDecimal balance;
    private Integer achievement;

    /** 是否持有有效会员卡 */
    private Boolean hasCard;

    /** 生效中的会员卡（大神卡 / 咖啡卡各至多一张），随概要一起返回省一次请求 */
    private List<MemberCardVO> cards;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime createdAt;

    public static MemberSummaryVO from(Member m) {
        if (m == null) {
            return null;
        }
        MemberSummaryVO vo = new MemberSummaryVO();
        vo.setId(m.getId());
        vo.setUserId(m.getUserId());
        vo.setMemberNo(m.getMemberNo());
        vo.setNickname(m.getNickname());
        vo.setLevel(m.getLevel());
        vo.setVgold(m.getVgold());
        vo.setCouponCount(m.getCouponCount());
        vo.setBalance(m.getBalance());
        vo.setAchievement(m.getAchievement());
        vo.setCreatedAt(m.getCreatedAt());
        vo.setHasCard(false);
        vo.setCards(new java.util.ArrayList<>());
        return vo;
    }
}
