package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.MemberCard;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.Setter;

import java.time.Duration;
import java.time.OffsetDateTime;

/**
 * 已开通会员卡出参
 *
 * <p>remainDays 由服务端算好：前端不做日期减法，避免设备时区不同算出不同天数。
 */
@Getter
@Setter
public class MemberCardVO {

    private Long id;
    private Long planId;
    private String cardType;
    private String cardName;
    private String cardNo;
    private String status;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime startAt;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime expireAt;

    /** 剩余天数，已过期返回 0 */
    private Long remainDays;

    public static MemberCardVO from(MemberCard c) {
        if (c == null) {
            return null;
        }
        MemberCardVO vo = new MemberCardVO();
        vo.setId(c.getId());
        vo.setPlanId(c.getPlanId());
        vo.setCardType(c.getCardType());
        vo.setCardName(c.getCardName());
        vo.setCardNo(c.getCardNo());
        vo.setStatus(c.getStatus());
        vo.setStartAt(c.getStartAt());
        vo.setExpireAt(c.getExpireAt());
        long days = 0L;
        if (c.getExpireAt() != null) {
            OffsetDateTime now = OffsetDateTime.now();
            if (c.getExpireAt().isAfter(now)) {
                days = Math.max(1L, Duration.between(now, c.getExpireAt()).toDays() + 1);
            }
        }
        vo.setRemainDays(days);
        return vo;
    }
}
