package com.pulseauth.pulseauth.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(
                        "http://localhost:4200",
                        "http://eks-rbac-dev-frontend.s3-website.ap-south-1.amazonaws.com"
                )
                .allowedMethods("GET", "POST", "DELETE")
                .allowedHeaders("*");
    }
}
