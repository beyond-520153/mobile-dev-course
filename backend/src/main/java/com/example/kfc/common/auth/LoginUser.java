package com.example.kfc.common.auth;

import com.example.kfc.domain.entity.User;
import lombok.Getter;
import lombok.Setter;

/**
 * 已登录用户 —— 会话载体
 *
 * <p>这个对象有三个身份，字段必须保持一致：
 * <ol>
 *   <li>JWT 的 payload（签发时塞进去）；</li>
 *   <li>Redis 里 {@code kfc:token:{token}} 的值（JSON）；</li>
 *   <li>请求线程上的 {@link UserContext}（拦截器放进来，Service 取）。</li>
 * </ol>
 *
 * <p>{@code godCard} 只是登录那一刻的快照，用于日志和前端首屏，
 * 真正的权限判断一律现查 {@code t_member_card} 的到期时间 —— 卡可能在会话期间开通或过期。
 */
@Getter
@Setter
public class LoginUser {

    private Long userId;
    private String username;
    private String nickname;
    private String role;

    /** 登录时是否手持大神卡（快照，仅供展示） */
    private Boolean godCard;

    /** 登录时间（epoch 毫秒） */
    private Long loginAt;

    public static LoginUser of(User user, boolean godCard) {
        LoginUser lu = new LoginUser();
        lu.setUserId(user.getId());
        lu.setUsername(user.getUsername());
        lu.setNickname(user.getNickname());
        lu.setRole(user.getRole() == null ? "CUSTOMER" : user.getRole().name());
        lu.setGodCard(godCard);
        lu.setLoginAt(System.currentTimeMillis());
        return lu;
    }

    /** 基础信息摘要，便于日志里一眼看出是谁 */
    public String describe() {
        return "userId=" + userId + ", username=" + username
                + (godCard != null && godCard ? ", godCard=true" : "");
    }
}
