package com.example.kfc.config;

import com.example.kfc.common.auth.AuthInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web 层配置
 *
 * <p>放开 CORS 只为本机联调服务：鸿蒙 App 走原生网络请求不受同源策略约束，
 * 但用浏览器打开静态联调页（resources/static/preview.html）时需要它。
 * 注意 {@code allowedHeaders("*")} 必须放开 Authorization，否则浏览器的预检会拒掉带 token 的请求。
 *
 * <p>拦截器只挂在 {@code /api/**} 上，静态资源与 preview.html 不受影响；
 * 登录与注册本身是「获取 token」的入口，如果不 exclude 就会永远进不去。
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final AuthInterceptor authInterceptor;

    public WebConfig(AuthInterceptor authInterceptor) {
        this.authInterceptor = authInterceptor;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .exposedHeaders("Authorization")
                .maxAge(3600);
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(authInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns("/api/users/login", "/api/users/register");
    }
}
