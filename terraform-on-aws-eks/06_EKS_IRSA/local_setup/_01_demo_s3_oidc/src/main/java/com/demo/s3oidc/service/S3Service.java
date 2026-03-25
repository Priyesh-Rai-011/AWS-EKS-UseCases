package com.demo.s3oidc.service;

import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class S3Service {

    private final S3Client s3Client;

    public S3Service(S3Client s3Client) {
        this.s3Client = s3Client;
    }

    // ── List all buckets ──────────────────────────────────────────
    public List<String> listBuckets() {
        return s3Client.listBuckets()
                .buckets()
                .stream()
                .map(Bucket::name)
                .toList();
    }

    // ── List top-level folders and files in a bucket ──────────────
    public void printS3Tree(String bucketName) {
        try {
            // Auto-detect the bucket's region
            String bucketRegion = s3Client.getBucketLocation(r -> r.bucket(bucketName))
                    .locationConstraintAsString();

            // If empty string, bucket is in us-east-1
            if (bucketRegion == null || bucketRegion.isBlank()) {
                bucketRegion = "us-east-1";
            }

            // Build a region-specific client for this bucket
            S3Client regionalClient = S3Client.builder()
                    .region(Region.of(bucketRegion))
                    .build();

            ListObjectsV2Request request = ListObjectsV2Request.builder()
                    .bucket(bucketName)
                    .delimiter("/")
                    .build();

            ListObjectsV2Response response = regionalClient.listObjectsV2(request);

            response.commonPrefixes().forEach(prefix ->
                    System.out.println("  └── [DIR]  " + prefix.prefix()));
            response.contents().forEach(obj ->
                    System.out.println("  ├── [FILE] " + obj.key() + " (" + obj.size() + " bytes)"));

        } catch (S3Exception e) {
            System.out.println("  ⚠ Skipped (no access or wrong region): " + e.getMessage());
        }
    }

    // ── Same as above but returns data (used by REST API) ─────────
    public S3TreeResponse getS3Tree(String bucketName) {
        ListObjectsV2Request request = ListObjectsV2Request.builder()
                .bucket(bucketName)
                .delimiter("/")
                .build();

        ListObjectsV2Response response = s3Client.listObjectsV2(request);

        List<String> folders = response.commonPrefixes()
                .stream()
                .map(CommonPrefix::prefix)
                .toList();

        List<String> files = response.contents()
                .stream()
                .map(S3Object::key)
                .toList();

        return new S3TreeResponse(bucketName, folders, files);
    }

    // ── Inner response record ─────────────────────────────────────
    public record S3TreeResponse(String bucket, List<String> folders, List<String> files) {}
}