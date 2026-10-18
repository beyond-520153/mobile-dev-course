package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.User;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 用户出参
 *
 * <p>刻意不含 password 字段：实体永远不会被直接序列化返回给客户端。
 */
@Getter
@Setter
public class UserVO {

    private Long id;
    private String username;
    private String phone;
    private String nickname;
    private String avatar;
    private String role;
    private Integer status;

    /** 统一按东八区、秒级精度输出，理由见 OrderVO */
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime createdAt;

    /** 仅在登录／注册成功时返回，其它接口为 null */
    private String token;

    /* ------------------------- 会员卡属性（大神卡） ------------------------- */

    /** 是否持有生效中的大神卡；下单时按它决定是否套用大神卡优惠 */
    private Boolean godCard;

    /** 卡类型：GOD / COFFEE */
    private String godCardType;

    /** 卡名：季卡 / 年卡 / 月卡 */
    private String godCardName;

    private String godCardNo;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private OffsetDateTime godCardExpireAt;

    /** 剩余天数，服务端算好，前端不做日期减法 */
    private Long godCardRemainDays;

    /** 会员等级：WOW会员（持卡）/ 普通会员 */
    private String memberLevel;

    /**
     * 当前可享权益清单（含今日剩余次数、是否在生效时段）
     *
     * <p>只在登录、注册、查详情时填充；列表接口不填，避免 N+1。
     */
    private List<UserBenefitVO> benefits;

    public static UserVO from(User u) {
        if (u == null) {
            return null;
        }
        UserVO vo = new UserVO();
        vo.setId(u.getId());
        vo.setUsername(u.getUsername());
        vo.setPhone(u.getPhone());
        vo.setNickname(u.getNickname());
        vo.setAvatar(u.getAvatar());
        vo.setStatus(u.getStatus());
        vo.setCreatedAt(u.getCreatedAt());
        // 默认按「未持卡」输出，service 侧查到卡再覆盖，避免前端拿到 null 要判空
        vo.setGodCard(false);
        vo.setMemberLevel("普通会员");
        vo.setBenefits(new java.util.ArrayList<>());
        if (u.getRole() != null) {
            vo.setRole(u.getRole().name());
        }
        return vo;
    }

    /**
     * 填充大神卡属性（由 UserService 在登录 / 查详情时调用）
     *
     * @param card     生效中的大神卡，未持卡传 null
     * @param benefits 当前可享权益
     */
    public void applyGodCard(MemberCardVO card, List<UserBenefitVO> benefits) {
        if (card != null) {
            setGodCard(true);
            setGodCardType(card.getCardType());
            setGodCardName(card.getCardName());
            setGodCardNo(card.getCardNo());
            setGodCardExpireAt(card.getExpireAt());
            setGodCardRemainDays(card.getRemainDays());
        } else {
            setGodCard(false);
        }
        boolean hasBenefits = benefits != null && !benefits.isEmpty();
        // 口径与会员服务一致：持有任意生效卡（大神卡 / 咖啡卡）即 WOW会员
        setMemberLevel(card != null || hasBenefits ? "WOW会员" : "普通会员");
        setBenefits(benefits == null ? new java.util.ArrayList<>() : benefits);
    }
}
