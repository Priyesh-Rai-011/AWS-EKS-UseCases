package com.demo.s3oidc.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
//import software.amazon.awssdk.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Client;

@Configuration
public class AwsConfig {

    @Value("${aws.region}")
    private String awsRegion;

    @Bean
    public S3Client s3Client() {
        return S3Client.builder()
                .region(Region.of(awsRegion))
                // No credentials here — SDK auto-detects:
                // On EKS   → IRSA token from pod
                // On local → ~/.aws/credentials file
                .build();
    }
}