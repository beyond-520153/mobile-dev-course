package com.example.kfc.service;

import com.example.kfc.domain.dto.MemberOpenDTO;
import com.example.kfc.domain.vo.MemberCardVO;
import com.example.kfc.domain.vo.MemberPlanVO;
import com.example.kfc.domain.vo.MemberSummaryVO;

import java.math.BigDecimal;
import java.util.List;

/**
 * 会员模块 —— 业务逻辑层接口
 */
public interface MemberService {

    /**
     * 会员概要（WOW 会员中心头部四格数据）
     *
     * <p>用户第一次访问时自动建账户，不做注册时的强依赖。
     */
    MemberSummaryVO getSummary(Long userId);

    /** 已开通的会员卡（只返回生效中的） */
    List<MemberCardVO> listCards(Long userId);

    /**
     * 在售档位
     *
     * @param cardType 可选，GOD / COFFEE；为空返回全部
     */
    List<MemberPlanVO> listPlans(String cardType);

    /** 开通／续费会员卡，返回开通后的最新会员概要 */
    MemberSummaryVO openCard(MemberOpenDTO dto);

    /**
     * 累计 V金（订单支付成功后调用，消费 1 元 = 1 V金）
     *
     * <p>故意不抛异常：会员累计失败不能把支付本身回滚掉。
     */
    void accrueVgold(Long userId, BigDecimal amount);
}
