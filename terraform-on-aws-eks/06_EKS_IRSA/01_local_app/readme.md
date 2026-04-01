# Things I learned along the way

## 000000


### The folder structure :

```

Volume serial number is 9841-2D5E
C:.
│   .gitignore
│   Dockerfile
│   pom.xml
│
├───.idea
│       .gitignore
│       compiler.xml
│       encodings.xml
│       jarRepositories.xml
│       misc.xml
│       vcs.xml
│       workspace.xml
│
└───src
    ├───main
    │   ├───java
    │   │   └───com
    │   │       └───demo
    │   │           └───s3oidc
    │   │               │   Main.java
    │   │               │
    │   │               ├───config
    │   │               │       AwsConfig.java
    │   │               │
    │   │               ├───controller
    │   │               │       S3Controller.java
    │   │               │
    │   │               └───service
    │   │                       S3Service.java
    │   │
    │   └───resources
    │           application.properties
    │
    └───test
        └───java

```
---

#### How to run & test the container in local setup:

```
docker run -p 8080:8080 `
  -e AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY" `
  -e AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY" `
  -e AWS_REGION="us-east-1" `
  -e AWS_BUCKET_NAME="your-demo-bucket-name" `
  priyeshrai711/s3-oidc-demo:latest

```