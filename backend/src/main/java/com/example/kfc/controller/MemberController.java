package com.example.kfc.controller;

import com.example.kfc.common.result.Result;
import com.example.kfc.domain.dto.MemberOpenDTO;
import com.example.kfc.domain.vo.MemberCardVO;
import com.example.kfc.domain.vo.MemberPlanVO;
import com.example.kfc.domain.vo.MemberSummaryVO;
import com.example.kfc.domain.vo.UserBenefitVO;
import com.example.kfc.service.BenefitService;
import com.example.kfc.service.MemberService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 会员模块 —— 控制层 Controller
 *
 * <p>对应前端两页：WOW 会员中心（summary / cards）与大神卡页（plans / cards 开通）。
 */
@RestController
@RequestMapping("/api/member")
public class MemberController {

    private final MemberService memberService;
    private final BenefitService benefitService;

    public MemberController(MemberService memberService, BenefitService benefitService) {
        this.memberService = memberService;
        this.benefitService = benefitService;
    }

    /** 会员概要：昵称 / 会员号 / V金 / 卡券 / 余额 / 成就 + 生效卡 */
    @GetMapping("/summary")
    public Result<MemberSummaryVO> summary(@RequestParam Long userId) {
        return Result.success(memberService.getSummary(userId));
    }

    /**
     * 在售档位
     *
     * @param cardType 可选，GOD 大神卡 / COFFEE 咖啡卡；不传返回全部
     */
    @GetMapping("/plans")
    public Result<List<MemberPlanVO>> plans(@RequestParam(required = false) String cardType) {
        return Result.success(memberService.listPlans(cardType));
    }

    /** 已开通（生效中）的会员卡 */
    @GetMapping("/cards")
    public Result<List<MemberCardVO>> cards(@RequestParam Long userId) {
        return Result.success(memberService.listCards(userId));
    }

    /** 开通 / 续费，同一类型在当前到期日上叠加 */
    @PostMapping("/cards")
    public Result<MemberSummaryVO> open(@Valid @RequestBody MemberOpenDTO dto) {
        return Result.success(memberService.openCard(dto));
    }

    /**
     * 当前用户可享的权益（大神卡 / 咖啡卡）
     *
     * <p>带今日已用次数与是否在生效时段；未持卡返回空数组。
     */
    @GetMapping("/benefits")
    public Result<List<UserBenefitVO>> benefits(@RequestParam Long userId) {
        return Result.success(benefitService.listBenefits(userId));
    }
}
