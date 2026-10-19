package com.example.kfc.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * AI 点餐相关配置（阿里云百炼 / 通义千问）
 *
 * <p>对应 application.yml 里的 {@code kfc.ai.*}。走的是百炼的
 * <b>OpenAI 兼容模式</b>（{@code /compatible-mode/v1}），所以请求体就是标准
 * {@code /chat/completions} 结构，不需要引入官方 SDK —— 一条 RestTemplate 就够，
 * 少一个依赖就少一份版本冲突。
 *
 * <p>api-key 千万不要硬编码进源码。yml 里写成
 * {@code api-key: ${KFC_AI_API_KEY:默认值}}，生产上用环境变量覆盖。
 */
@Component
@ConfigurationProperties(prefix = "kfc.ai")
@Getter
@Setter
public class AiProperties {

    /** 总开关：关掉后接口直接返回本地兜底推荐，不发起外部请求（离线演示用） */
    private boolean enabled = true;

    /** 兼容模式基址，不带尾斜杠 */
    private String baseUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1";

    /** 百炼 API Key */
    private String apiKey = "";

    /** 模型名，qwen3.8-flash */
    private String model = "qwen3.8-flash";

    /** 建连超时（毫秒） */
    private int connectTimeoutMs = 5000;

    /** 读超时（毫秒）。flash 模型 + 关闭思考后通常 2~4 秒，留足余量 */
    private int readTimeoutMs = 40000;

    /** 采样温度：点餐推荐要稳定，别太发散 */
    private double temperature = 0.6;

    /** 输出上限。6 条推荐 + 一句回复，900 足够，超了就是模型跑偏 */
    private int maxTokens = 900;

    /* ------------------------- 门店信息（展示用） ------------------------- */

    /**
     * 门店名。菜单是浙江农林大学东湖校区店（HZ2226）的官方数据，
     * 所以这里固定成同一家门店，避免「推荐的是这家、地址写的是那家」。
     */
    private String storeName = "农林大学餐厅";

    /** 门店地址 */
    private String storeAddress = "临安区武肃街666号浙江农林大学东湖校区";

    /** 距离文案，前端直接展示 */
    private String storeDistance = "581m";
}
