package com.example.kfc.service;

import com.example.kfc.domain.vo.CartItemVO;
import com.example.kfc.domain.vo.MemberCardVO;
import com.example.kfc.domain.vo.OrderQuoteVO;
import com.example.kfc.domain.vo.UserBenefitVO;

import java.time.LocalDate;
import java.util.List;

/**
 * 会员卡权益 —— 业务逻辑层接口
 *
 * <p>下单时「按卡打折」的全部逻辑都在这里，订单服务只负责调用：
 * <ol>
 *   <li>下单前 {@link #quote} 试算，得到商品金额、外送费、优惠明细、应付金额；</li>
 *   <li>下单成功 {@link #consume} 扣当日次数；</li>
 *   <li>取消订单 {@link #release} 把次数还回去。</li>
 * </ol>
 * 试算与下单价用同一个方法，避免两套算法对不上。
 */
public interface BenefitService {

    /**
     * 结算试算（不写库、不扣次数）
     *
     * @param userId     下单用户，可为 null（未登录按原价）
     * @param pickupType PICKUP / DELIVERY
     * @param items      购物车明细
     */
    OrderQuoteVO quote(Long userId, String pickupType, List<CartItemVO> items);

    /** 下单成功后扣当日次数，返回实际用掉的规则编码 */
    List<String> consume(Long userId, OrderQuoteVO quote);

    /** 取消订单时归还次数（按订单创建那天记在流水上） */
    void release(Long userId, String benefitCodes, LocalDate useDate);

    /** 用户手上卡对应的权益清单，带今日剩余次数与时段状态 */
    List<UserBenefitVO> listBenefits(Long userId);

    /** 生效中的大神卡，没有返回 null */
    MemberCardVO activeGodCard(Long userId);

    /** 是否大神卡持有者 */
    boolean isGodCardOwner(Long userId);

    /**
     * 给餐品列表叠加「当前登录用户的会员价」
     *
     * <p>用户身份从 {@link com.example.kfc.common.auth.UserContext} 取（拦截器已放好），
     * 未登录或手上没有生效卡时什么都不做 —— 字段保持 null，前端就不展示专属价。
     * 只在出参阶段调用，绝不写进餐品缓存。
     */
    void fillMemberPrice(List<com.example.kfc.domain.vo.ProductVO> products);
}
