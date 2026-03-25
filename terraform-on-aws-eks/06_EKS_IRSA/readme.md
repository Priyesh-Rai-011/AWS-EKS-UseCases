# Kubernetes IAM Role for Service Account.

##

```

┌──────────────┐ 1. Pod starts
│ EKS Pod      │
│ (boto3 app)  │
└──────┬───────┘
       │ 2. K8s mounts ServiceAccount JWT
       ▼ (/var/run/secrets/eks.amazonaws.com/serviceaccount/token)
┌──────────────┐
│ ServiceAccount│ ←── Annotated with IAM Role ARN
│ (s3-reader-sa)│
└──────┬───────┘
       │ 3. App calls AWS SDK
       ▼
┌──────────────┐ 4. SDK reads JWT token
│ AWS SDK      │ ───── JWT ───────┐
│ (boto3)      │                  │
└──────┬───────┘                  │ 5. STS AssumeRoleWithWebIdentity
       │                          ▼
       │                 ┌─────────────────┐
       │                 │ EKS OIDC        │
       │                 │ Provider        │
       │                 │ (trusted by AWS)│
       │                 └─────────┬───────┘
       │                           │ 6. Validates JWT → Returns temp creds
       │                           ▼
       │                  ┌─────────────────┐
       │                  │ IAM Role        │ ──> S3:GetObject
       │                  │ (S3ReaderRole)  │
       │                  └─────────────────┘
       │ 7. App gets temp AWS_ACCESS_KEY_ID (1hr)

```

---

### Key items for IRSA Implementation

- AWS IAM Identity Provider.
- AWS STS AssumeRoleWithWebIdentity API operation.
- AWS IAM Temporary role Credentials.

- EKS Cluster OpenID Connect Provider.
- Kubernetes Service Accounts.
- Kubernetes ProjectedServiceAccountToken feature (OIDC JSON Web Token).

