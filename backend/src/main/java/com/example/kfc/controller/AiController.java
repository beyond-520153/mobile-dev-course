package com.example.kfc.controller;

import com.example.kfc.common.result.Result;
import com.example.kfc.domain.dto.AiChatDTO;
import com.example.kfc.domain.vo.AiRecommendVO;
import com.example.kfc.service.AiService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * AI 点餐 —— 控制层 Controller
 *
 * <p>只暴露两个端点：
 * <ul>
 *   <li>{@code POST /api/ai/recommend}：出推荐，匿名可用（没登录就是没有会员价）；</li>
 *   <li>{@code GET  /api/ai/health}：看模型通不通，排查配置用。</li>
 * </ul>
 *
 * <p>鉴权说明：recommend 在 {@code AuthInterceptor} 里属于「公开 POST」，
 * 未登录也能用 —— 点餐页首屏本来就允许游客逛菜单，AI 推荐没理由拦。
 * 带了有效 token 时会走 UserContext，卡片上会出现大神卡专属价。
 */
@RestController
@RequestMapping("/api/ai")
public class AiController {

    private final AiService aiService;

    public AiController(AiService aiService) {
        this.aiService = aiService;
    }

    /**
     * 生成推荐
     *
     * @param dto 可为空（等同于「刚进店」）；body 里 message 为空也表示首屏
     */
    @PostMapping("/recommend")
    public Result<AiRecommendVO> recommend(@RequestBody(required = false) AiChatDTO dto) {
        AiChatDTO body = dto == null ? new AiChatDTO() : dto;
        return Result.success(aiService.recommend(body));
    }

    @GetMapping("/health")
    public Result<Map<String, Object>> health() {
        return Result.success(aiService.health());
    }
}
