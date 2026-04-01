# Kubernetes IAM Role for Service Account.

References:
- https://platformwale.blog/2023/08/02/iam-roles-for-service-accounts-irsa-in-aws-eks-within-and-cross-aws-accounts/
- https://medium.com/@anil.goyal0057/implementing-and-understanding-iam-roles-for-service-accounts-in-aws-eks-00e8fd2a0262
- https://medium.com/@subhampradhan966/implementing-and-verifying-kubernetes-service-accounts-a-step-by-step-guide-c43b727260b2
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- some other link

## Things I learned along the way :

```
A. On-premise Kubernetes cluster.
Q1. What do we mean by 'access control' inside the cluster resources?
Q2. What do we mean by access control of outside cluster resources?
Q3. How & what do we do to implement access control for resources outside the cluster?
Q4. How & what do we do to implement access control for resources inside the cluster?

B. AWS EKS cluster.
Q1. What do we mean by 'access control' inside the cluster resources?
Q2. What do we mean by access control of outside cluster resources?
Q3. How & what do we do to implement access control for resources outside the cluster?
Q4. How & what do we do to implement access control for resources inside the cluster?

C. How & where do IRSA & RBAC play a role in all this? 
D. How do we implement that thing? Developers & QA people can't make changes (like changing the Docker image tag) and apply the Kubernetes manifest files, but the DevOps and SRE people can.
```

### Answers I found out.

IAM Roles for Service Accounts (IRSA) is a feature in AWS EKS that allows Kubernetes service accounts to be associated with IAM roles. This provides a secure and efficient way to give your applications running on EKS the permissions they need to call other AWS services.


```

┌────────────────┐ 1. Pod starts
│ EKS Pod        │
│ (JDK   Maven)  │
└──────┬─────────┘
       │
       │ 2. K8s mounts ServiceAccount JWT
       │
       │ (/var/run/secrets/eks.amazonaws.com/serviceaccount/token)
       │
       ▼ 
┌──────────────┐
│ ServiceAccount│ ←── Annotated with IAM Role ARN
│ (s3-reader-sa)│
└──────┬───────┘
       │
       │ 3. App calls AWS SDK
       │
       ▼
┌──────────────┐          4. SDK reads JWT token
│ AWS SDK      │ ───────────── JWT ───────┐
│ (boto3)      │                          │        
│              │                          │
└──────┬───────┘                          │ 5. STS AssumeRoleWithWebIdentity
       │                                  ▼
       │                         ┌─────────────────┐
       │                         │ EKS OIDC        │
       │                         │ Provider        │
       │                         │ (trusted by AWS)│
       │                         └─────────┬───────┘
       │                                   │ 
       │                                   │ 6. Validates JWT → Returns temp creds
       │                                   ▼
       │                          ┌─────────────────┐
       │                          │ IAM Role        │ ──> S3:GetObject
       │                          │ (S3ReaderRole)  │
       │                          └─────────────────┘
       │
       │
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

### Well I guess, this is how the Service account works :

```

─────────────────────────────────────────────────────────────────────────
                        AWS ACCOUNT
─────────────────────────────────────────────────────────────────────────

  ┌─── IAM (Identity & Access Management) ────────────────────────────┐
  │                                                                   │
  │   IAM Role: "s3-demo-role"                                        │
  │   ┌──────────────────────────────────────────────────┐            │
  │   │  Trust Policy  (WHO can assume this role?)       │            │
  │   │                                                  │            │
  │   │  "I trust tokens from OIDC Provider:             │            │
  │   │   oidc.eks.ap-south-1.amazonaws.com/id/ABC123    │            │
  │   │   BUT ONLY IF the token belongs to               │            │
  │   │   ServiceAccount: s3-demo-sa                     │            │
  │   │   in Namespace:   default"                       │            │
  │   └──────────────────────────────────────────────────┘            │
  │                                                                   │
  │   Permission Policy (WHAT can this role do?)                      │
  │   ┌──────────────────────────────────────────────────┐            │
  │   │  s3:ListAllMyBuckets                             │            │
  │   │  s3:GetObject                                    │            │
  │   │  s3:PutObject                                    │            │
  │   └──────────────────────────────────────────────────┘            │
  │                                                                   │
  └───────────────────────────────────────────────────────────────────┘

  ┌─── OIDC Provider (registered in IAM) ─────────────────────────────┐
  │                                                                   │
  │   URL: oidc.eks.ap-south-1.amazonaws.com/id/ABC123                │
  │                                                                   │
  │   This is just a TRUST BRIDGE registered once per EKS cluster.    │
  │   AWS IAM says: "I will trust JWT tokens signed by this URL"      │
  │                                                                   │
  └───────────────────────────────────────────────────────────────────┘

─────────────────────────────────────────────────────────────────────────
                        EKS CLUSTER
─────────────────────────────────────────────────────────────────────────

  ┌─── Kubernetes Objects (written in YAML manifests) ─────────────────┐
  │                                                                    │
  │   ServiceAccount                                                   │
  │   ┌──────────────────────────────────────────────────┐             │
  │   │  apiVersion: v1                                  │             │
  │   │  kind: ServiceAccount                            │             │
  │   │  metadata:                                       │             │
  │   │    name: s3-demo-sa                              │             │
  │   │    namespace: default                            │             │
  │   │    annotations:                                  │             │
  │   │      eks.amazonaws.com/role-arn:                 │             │
  │   │        arn:aws:iam::123456:role/s3-demo-role  ◄──┼── THE LINK  │
  │   └──────────────────────────────────────────────────┘             │
  │              │                                                     │
  │              │  "I am bound to this IAM Role"                      │
  │              ▼                                                     │
  │   Deployment / Pod                                                 │
  │   ┌──────────────────────────────────────────────────┐             │
  │   │  spec:                                           │             │
  │   │    serviceAccountName: s3-demo-sa    ◄── Pod uses this SA      │
  │   │    containers:                                   │             │
  │   │      - name: s3-app                              │             │
  │   │        image: priyeshrai711/s3-oidc-demo:latest  │             │
  │   └──────────────────────────────────────────────────┘             │
  │              │                                                     │
  │              │  EKS automatically mounts a JWT token file          │
  │              ▼  inside the container at runtime                    │
  │   Inside the Container (auto-injected by EKS)                      │
  │   ┌────────────────────────────────────────────────────┐           │
  │   │  /var/run/secrets/eks.amazonaws.com/serviceaccount │           │
  │   │    └── token   (a signed JWT file)                 │           │
  │   │                                                    │           │
  │   │  The JWT says:                                     │           │
  │   │    "I am ServiceAccount s3-demo-sa                 │           │
  │   │     in namespace default                           │           │
  │   │     signed by OIDC provider ABC123"                │           │
  │   └────────────────────────────────────────────────────┘           │
  │                                                                    │
  └────────────────────────────────────────────────────────────────────┘

─────────────────────────────────────────────────────────────────────────
                    THE CREDENTIAL EXCHANGE FLOW
─────────────────────────────────────────────────────────────────────────

  Your Java App (inside Pod)
        │
        │  1. AWS SDK reads the mounted JWT token file
        │
        ▼
  AWS STS (Security Token Service)
        │
        │  2. "Here is my JWT token, I want to assume s3-demo-role"
        │
        ▼
  IAM checks Trust Policy
        │
        │  3. "Does this token come from trusted OIDC provider?" ✓
        │     "Is it for ServiceAccount s3-demo-sa?"            ✓
        │     "Is it in namespace default?"                      ✓
        │
        ▼
  STS returns Temporary Credentials
        │
        │  4. AccessKeyId + SecretKey + SessionToken (valid 1hr)
        │
        ▼
  Your Java App calls S3 API
        │
        │  5. S3 checks: does s3-demo-role have s3:ListBuckets? ✓
        │
        ▼
  S3 responds with bucket list  ✓

```