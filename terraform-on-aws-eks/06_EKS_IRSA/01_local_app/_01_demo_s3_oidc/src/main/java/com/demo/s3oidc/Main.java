package com.demo.s3oidc;

//import software.amazon.awssdk.regions.Region;

import com.demo.s3oidc.service.S3Service;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ApplicationContext;

@SpringBootApplication
public class Main {

    public static void main(String[] args) {
        ApplicationContext ctx = SpringApplication.run(Main.class, args);

        // --- Standalone runner logic (runs once on startup) ---
        S3Service s3Service = ctx.getBean(S3Service.class);
        String bucket = ctx.getEnvironment().getProperty("aws.bucket.name");

//        System.out.println("\n========== S3 TREE ==========");
//        s3Service.printS3Tree(bucket);
//        System.out.println("==============================\n");
//        // REST API continues running after this
        System.out.println("\n=========  S3 Tree  ===========");
        s3Service.listBuckets().forEach(buckets -> {
            System.out.println("\nBucket: " + buckets);
            s3Service.printS3Tree(buckets);
        });
        System.out.println("\n===============================");
    }
}