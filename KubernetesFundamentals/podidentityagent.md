# EKS Pod Identity Agent vs IRSA — A Deep Dive

> Personal learning notes on how AWS handles IAM permissions for workloads running inside EKS clusters. This covers the evolution from node-level IAM roles → IRSA → Pod Identity Agent, with real scenarios and diagrams.

---

## Table of Contents

- [The Root Problem — Node IAM Role](#the-root-problem--node-iam-role)
- [IRSA — IAM Roles for Service Accounts](#irsa--iam-roles-for-service-accounts)
- [Pod Identity Agent — The Modern Approach](#pod-identity-agent--the-modern-approach)
- [Real Scenario — Multiple Services in a Cluster](#real-scenario--multiple-services-in-a-cluster)
- [IRSA vs Pod Identity — Side by Side](#irsa-vs-pod-identity--side-by-side)
- [How Does the Agent Know Which IAM Role to Use?](#how-does-the-agent-know-which-iam-role-to-use)
- [The Mapping — Where is it Stored?](#the-mapping--where-is-it-stored)
- [Procedure — How to Set Up Pod Identity](#procedure--how-to-set-up-pod-identity)
- [Key Takeaways](#key-takeaways)

---

## The Root Problem — Node IAM Role

Before IRSA existed, every EC2 node in your EKS cluster had an **IAM role attached to it** — called the **node instance role**. Since all pods run on those nodes, every pod inherited those IAM permissions automatically through the EC2 instance metadata service (IMDS).

```
Node has IAM Role
    ↓
All pods on that node can call AWS APIs using that role
    ↓
No isolation between workloads — at all
```

This is a serious security problem. Your nginx pod has the same AWS access as your secrets manager pod. There is zero granularity.

### Best Practice for Node IAM Role

Keep it minimal — only what the node itself needs to function:

- ECR pull access (to pull container images)
- VPC CNI permissions (for pod networking)
- EBS / EFS permissions (if using persistent volumes)
- Nothing else

**IRSA and Pod Identity were both invented to solve this exact problem** — giving each workload its own AWS credentials instead of sharing the node role.

---

## IRSA — IAM Roles for Service Accounts

IRSA introduced **per-workload AWS credentials** using Kubernetes Service Accounts + AWS OIDC federation.

### How IRSA Works

```
Pod requests AWS credentials
        ↓
AWS SDK reads the service account token mounted in the pod
        ↓
Token is sent to AWS STS (AssumeRoleWithWebIdentity)
        ↓
AWS validates the token against the cluster's OIDC provider
        ↓
STS returns temporary credentials for the mapped IAM role
        ↓
Pod uses those credentials to call AWS APIs
```

### The Three Parts of IRSA

**1. OIDC Provider** — registered at the cluster level in IAM. One per EKS cluster. This is what allows AWS to trust tokens issued by your Kubernetes cluster.

**2. IAM Role Trust Policy** — this is where the real isolation happens. The trust policy hardcodes the OIDC provider URL and locks the role down to a specific namespace + service account:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::006600133483:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:sub":
            "system:serviceaccount:dev:svc-backend-sa",
          "oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:aud":
            "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

**3. ServiceAccount Annotation** — the annotation on the Kubernetes SA tells the pod which IAM role to assume:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: svc-backend-sa
  namespace: dev
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::006600133483:role/eks-dev-backend-role
```

### The Two Condition Keys Explained

| Key | Value | Purpose |
|-----|-------|---------|
| `:sub` (Subject) | `system:serviceaccount:<namespace>:<sa-name>` | Identifies **who** is requesting — locks down to a specific SA in a specific namespace |
| `:aud` (Audience) | `sts.amazonaws.com` | Ensures the token is only valid for AWS STS — prevents token replay elsewhere |

Without `:sub` → any service account in the entire cluster can assume the role (very bad).  
Without `:aud` → the JWT token could potentially be replayed against other systems (security risk).

### The Isolation Chain in IRSA

```
IAM Role trust policy
    → allows specific namespace + ServiceAccount (:sub condition)
        → ServiceAccount is referenced by a specific Deployment
            → only those pods get the credentials
```

---

## Pod Identity Agent — The Modern Approach

Pod Identity Agent is a **DaemonSet** (`eks-pod-identity-agent`) that runs on every node in your cluster. It intercepts credential requests from pods and returns temporary AWS credentials based on a mapping you configure in AWS.

### Why Was It Built If IRSA Already Worked?

IRSA had real operational pain at scale:

**Problem 1 — OIDC provider per cluster**  
Every new EKS cluster requires creating and managing a new OIDC provider in IAM. 10 clusters = 10 OIDC providers.

**Problem 2 — Trust policy hardcodes the cluster OIDC URL**  
Every IAM role has this long URL baked into its trust policy:
```
oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E
```
50 microservices = 50 IAM roles, each with this URL hardcoded. If you **recreate the cluster**, the OIDC URL changes and you must update every single trust policy. This is a real operational nightmare.

**Problem 3 — Role reuse across clusters is painful**  
Same workload across dev/staging/prod? Each cluster has a different OIDC URL. You end up adding multiple trust policy statements per role — and trust policies have size limits.

### Pod Identity Fixes All of This

The trust policy becomes completely generic — no OIDC URL, no cluster-specific hardcoding:

```json
{
  "Principal": {
    "Service": "pods.eks.amazonaws.com"
  },
  "Action": [
    "sts:AssumeRole",
    "sts:TagSession"
  ]
}
```

The isolation (namespace + SA) moves to an **AWS-side association** that you create once:

```bash
aws eks create-pod-identity-association \
  --cluster-name dev-cluster \
  --namespace dev \
  --service-account svc-backend-sa \
  --role-arn arn:aws:iam::006600133483:role/eks-dev-backend-role
```

The ServiceAccount YAML becomes clean — no annotation needed:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: svc-backend-sa
  namespace: dev
  # no annotation needed
```

### The Pivoting Point in One Line

> With IRSA, the **IAM role knows about the cluster**.  
> With Pod Identity, the **cluster knows about the IAM role**.

That inversion removes cluster-specific coupling from your IAM roles, making them portable and much easier to manage at scale.

---

## Real Scenario — Multiple Services in a Cluster

Let's make this concrete. You have a real cluster with multiple workloads:

```
Namespace: dev

Deployments:
1. svc-backend        → needs Secrets Manager + S3
2. svc-auth           → needs Secrets Manager + Cognito
3. svc-worker         → needs SQS + S3
4. svc-cronjob        → needs DynamoDB
5. svc-nginx          → needs nothing from AWS
6. svc-cache          → needs nothing from AWS
```

### How IRSA Handles This

**Step 1 — Create an IAM role per workload, each with the OIDC URL hardcoded:**

```json
// For svc-backend — and you repeat this pattern for every service
{
  "Federated": "arn:aws:iam::006600133483:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/ABC123",
  "Condition": {
    "StringEquals": {
      "...ABC123:sub": "system:serviceaccount:dev:svc-backend-sa",
      "...ABC123:aud": "sts.amazonaws.com"
    }
  }
}
// eks-dev-auth-role    → same OIDC URL hardcoded again
// eks-dev-worker-role  → same OIDC URL hardcoded again
// eks-dev-cronjob-role → same OIDC URL hardcoded again
```

**Step 2 — Annotate every ServiceAccount:**

```yaml
# svc-backend-sa
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::006600133483:role/eks-dev-backend-role

# svc-auth-sa
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::006600133483:role/eks-dev-auth-role

# svc-worker-sa
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::006600133483:role/eks-dev-worker-role

# svc-cronjob-sa
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::006600133483:role/eks-dev-cronjob-role
```

**Step 3 — Reference SA in each Deployment:**

```yaml
spec:
  serviceAccountName: svc-backend-sa
```

---

### How Pod Identity Handles the Same Scenario

**Step 1 — Create IAM roles with a generic, reusable trust policy (same for all roles):**

```json
{
  "Principal": {
    "Service": "pods.eks.amazonaws.com"
  },
  "Action": ["sts:AssumeRole", "sts:TagSession"]
}
```

**Step 2 — Register mappings in AWS once:**

```bash
aws eks create-pod-identity-association \
  --cluster-name dev-cluster --namespace dev \
  --service-account svc-backend-sa \
  --role-arn arn:aws:iam::006600133483:role/eks-dev-backend-role

aws eks create-pod-identity-association \
  --cluster-name dev-cluster --namespace dev \
  --service-account svc-auth-sa \
  --role-arn arn:aws:iam::006600133483:role/eks-dev-auth-role

aws eks create-pod-identity-association \
  --cluster-name dev-cluster --namespace dev \
  --service-account svc-worker-sa \
  --role-arn arn:aws:iam::006600133483:role/eks-dev-worker-role

aws eks create-pod-identity-association \
  --cluster-name dev-cluster --namespace dev \
  --service-account svc-cronjob-sa \
  --role-arn arn:aws:iam::006600133483:role/eks-dev-cronjob-role
```

**Step 3 — Clean ServiceAccounts, no annotations:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: svc-backend-sa
  namespace: dev
  # clean — nothing here
```

**Step 4 — Deployments reference SA exactly the same as before:**

```yaml
spec:
  serviceAccountName: svc-backend-sa
```

---

### What About Cluster Recreation?

**With IRSA:**
```
New cluster → New OIDC URL →
Go update trust policy of ALL 4 IAM roles →
Miss one → that service breaks
```

**With Pod Identity:**
```
New cluster →
Run create-pod-identity-association again for each service →
IAM roles untouched
```

---

## IRSA vs Pod Identity — Side by Side

| | IRSA | Pod Identity |
|---|---|---|
| IAM role trust policy | Hardcoded OIDC URL per cluster | Generic, reusable across clusters |
| SA annotation | Required on every SA | Not needed |
| Mapping location | Inside SA yaml (annotation) | AWS API (`create-pod-identity-association`) |
| OIDC provider setup | Required per cluster | Not needed |
| Cluster recreation impact | Must update ALL trust policies | Zero impact |
| Role reuse across clusters | Add multiple trust statements | Same role, new association only |
| Isolation mechanism | `:sub` + `:aud` in trust policy | namespace + SA name in association |
| Node IAM role dependency | No | No |

---

## How Does the Agent Know Which IAM Role to Use?

This is the most important question. The answer is: **the ServiceAccount is the mapping key**.

### The Full Chain

```
IAM Role
    ↑
Pod Identity Association  (namespace + ServiceAccount name → IAM Role)
    ↑
ServiceAccount
    ↑
Deployment (serviceAccountName field)
    ↑
Pod
```

### At Runtime — Step by Step

```
svc-backend pod starts
        ↓
Pod makes an AWS SDK call → needs credentials
        ↓
Pod Identity Agent intercepts at http://169.254.170.23/v1/credentials
        ↓
Agent reads:
  - cluster_name  → from node configuration
  - namespace     → from pod spec
  - SA name       → from pod spec (serviceAccountName field)
        ↓
Agent queries AWS EKS API with those 3 values as the lookup key
        ↓
AWS returns → eks-dev-backend-role
        ↓
Agent calls STS AssumeRole → gets temporary credentials
        ↓
Credentials returned to the pod
```

### The Mapping is One-to-One

```
svc-backend-sa  →  eks-dev-backend-role  (Secrets Manager + S3)
svc-worker-sa   →  eks-dev-worker-role   (SQS + S3)
svc-auth-sa     →  eks-dev-auth-role     (Cognito)
svc-cronjob-sa  →  eks-dev-cronjob-role  (DynamoDB)
```

One ServiceAccount → One IAM Role. That is the rule.

### What About Multiple Replicas?

```
svc-backend has 5 replicas
        ↓
All 5 pods use svc-backend-sa
        ↓
All 5 pods get credentials for eks-dev-backend-role
```

Many pods → One ServiceAccount → One IAM Role. This is expected and fine.

### Can Two Deployments Share the Same SA?

Yes. If two deployments need the same AWS access, they can reference the same ServiceAccount and they will both get the same IAM role credentials. This is intentional and supported.

### Can One SA Map to Multiple IAM Roles?

No. One ServiceAccount → one IAM role, strictly. That is the constraint.

---

## The Mapping — Where is it Stored?

The association table lives entirely on the **AWS side** — not inside etcd, not inside the cluster, not in any Kubernetes resource. AWS manages it internally.

Conceptually it looks like this:

```
┌─────────────────┬───────────────┬──────────────────────┬─────────────────────────────────────────┐
│  cluster_name   │  namespace    │  service_account     │  role_arn                               │
├─────────────────┼───────────────┼──────────────────────┼─────────────────────────────────────────┤
│  dev-cluster    │  dev          │  svc-backend-sa      │  arn:aws:iam::123456:role/backend-role  │
│  dev-cluster    │  dev          │  svc-worker-sa       │  arn:aws:iam::123456:role/worker-role   │
│  dev-cluster    │  dev          │  svc-auth-sa         │  arn:aws:iam::123456:role/auth-role     │
│  prod-cluster   │  prod         │  svc-backend-sa      │  arn:aws:iam::123456:role/backend-role  │
└─────────────────┴───────────────┴──────────────────────┴─────────────────────────────────────────┘
```

The lookup key is a **composite key**:

```
cluster_name + namespace + service_account_name
        ↓
unique combination → maps to one IAM role
```

Think of it like a HashMap:
```
Key   →  (cluster_name, namespace, service_account_name)
Value →  role_arn
```

### Important Implication

Since the map lives on AWS side — **deleting and recreating your cluster does not wipe the associations**. They persist in AWS. You only need to re-run the associations if you create a brand new cluster with a different name.

### Verify the Associations Yourself

```bash
# list all associations in your cluster
aws eks list-pod-identity-associations \
  --cluster-name dev-cluster

# output
{
  "associations": [
    {
      "clusterName": "dev-cluster",
      "namespace": "dev",
      "serviceAccount": "svc-backend-sa",
      "associationId": "a-xxxxxxxxxxxx",
      "roleArn": "arn:aws:iam::123456:role/backend-role"
    }
  ]
}
```

---

## Procedure — How to Set Up Pod Identity

This is **not automatic** like an ALB Ingress Controller. You create the associations yourself — via CLI, Console, or Terraform.

### Correct Order of Operations

```
1. Create the AWS service (S3 / Secrets Manager / SQS etc.)
        ↓
2. Create the IAM Policy (what actions are allowed on that service)
        ↓
3. Create the IAM Role (with generic Pod Identity trust policy)
        ↓
4. Attach the policy to the role
        ↓
5. Create EKS Cluster
        ↓
6. Install Pod Identity Agent addon on the cluster
        ↓
7. Create Kubernetes ServiceAccount
        ↓
8. Create Pod Identity Association   ← you do this manually
        ↓
9. Deploy your workload referencing the SA
```

### Via AWS CLI

```bash
aws eks create-pod-identity-association \
  --cluster-name dev-cluster \
  --namespace dev \
  --service-account svc-backend-sa \
  --role-arn arn:aws:iam::006600133483:role/eks-dev-backend-role
```

### Via AWS Console

```
EKS → Cluster → Access tab → Pod Identity Associations → Create
```

### Via Terraform (recommended for production)

```hcl
resource "aws_eks_pod_identity_association" "backend" {
  cluster_name    = aws_eks_cluster.dev.name
  namespace       = "dev"
  service_account = "svc-backend-sa"
  role_arn        = aws_iam_role.backend.arn
}
```

Terraform is the right approach because you define all associations as code alongside your IAM roles and EKS cluster — nothing is missed and everything is version controlled.

### Install Pod Identity Agent Addon

```bash
aws eks create-addon \
  --cluster-name dev-cluster \
  --addon-name eks-pod-identity-agent
```

Or via Terraform:

```hcl
resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.dev.name
  addon_name   = "eks-pod-identity-agent"
}
```

---

## Key Takeaways

### The Evolution of Pod-Level AWS Auth

```
Node IAM Role (everyone shares — no isolation)
        ↓ problem identified
IRSA (per workload isolation via OIDC + SA annotation)
        ↓ operational pain at scale
Pod Identity Agent (same isolation, cleaner mapping, no OIDC)
```

### The Full Chain (Pod Identity)

```
AWS Service (S3 / Secrets Manager / SQS)
        ↑
IAM Policy (permissions)
        ↑
IAM Role (generic trust policy — no OIDC hardcoding)
        ↑
Pod Identity Association (cluster + namespace + SA → role)
        ↑
Kubernetes ServiceAccount
        ↑
Deployment (serviceAccountName field)
        ↑
Pod (gets temporary credentials at runtime)
```

### Rules to Remember

- The **ServiceAccount name + namespace** is the exact lookup key
- One ServiceAccount → One IAM Role (strictly one-to-one)
- Many pods can share one SA → they all get the same role (expected)
- The mapping table lives on **AWS side**, not inside the cluster
- Associations must be created **manually** — nothing creates them automatically
- Pod Identity Agent has **no other purpose** — it only vends credentials

---

*Learning notes — EKS IAM authentication deep dive.*
