package com.demo.s3oidc.controller;

import com.demo.s3oidc.service.S3Service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/s3")
public class S3Controller {

    private final S3Service s3Service;

    @Value("${aws.bucket.name}")
    private String defaultBucket;

    public S3Controller(S3Service s3Service) {
        this.s3Service = s3Service;
    }

    // GET /api/s3/buckets
    @GetMapping("/buckets")
    public List<String> listBuckets() {
        return s3Service.listBuckets();
    }

    // GET /api/s3/tree                    ← uses bucket from application.properties
    // GET /api/s3/tree?bucket=my-bucket   ← override with query param
    @GetMapping("/tree")
    public S3Service.S3TreeResponse getTree(
            @RequestParam(required = false) String bucket) {
        String targetBucket = (bucket != null && !bucket.isBlank()) ? bucket : defaultBucket;
        return s3Service.getS3Tree(targetBucket);
    }
}