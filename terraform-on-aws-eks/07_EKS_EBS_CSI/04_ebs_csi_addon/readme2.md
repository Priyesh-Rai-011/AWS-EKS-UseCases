# EBS CSI + ESO + IRSA — How It All Works

This folder deploys a full production-grade setup: EKS cluster with EBS storage,
External Secrets Operator pulling credentials from AWS Secrets Manager, and a
Spring Boot UMS app + Postgres StatefulSet running on top of it.

---

## The Big Picture

```
Developer pushes code to GitHub
         │
         ▼
    [ In Production: ArgoCD watches the repo ]
    [ In our setup:  kubectl apply manually  ]
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│                   EKS Cluster (eks-public-dev)           │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  external-secrets namespace                       │   │
│  │  ┌────────────────────┐                          │   │
│  │  │  ESO Controller    │  watches SecretStore +   │   │
│  │  │  (pod)             │  ExternalSecret CRDs     │   │
│  │  └────────────────────┘                          │   │
│  └──────────────────────────────────────────────────┘   │
│                      │                                   │
│                       │ fetches secret using             │
│                       │ ums-app-sa JWT token (IRSA)      │
│                      ▼                                   │
│  ┌──────────────────────────────────────────────────┐   │
│  │  ums-app namespace                                │   │
│  │                                                   │   │
│  │  SecretStore ──────────────────► AWS SM           │   │
│  │  ExternalSecret                                   │   │
│  │       │ creates                                   │   │
│  │       ▼                                           │   │
│  │  postgres-secret (k8s Secret)                    │   │
│  │       │ mounted as env vars                       │   │
│  │       ▼                         ▼                 │   │
│  │  postgres-0 (StatefulSet)   ums-app (Deployment) │   │
│  │       │                          │                │   │
│  │       └──── EBS Volume (5Gi) ────┘                │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         │
         │ reads credentials from
         ▼
┌──────────────────────┐
│  AWS Secrets Manager  │
│  eks-public-dev/      │
│    ums/postgres       │
│  { DB, USER, PASS }  │
└──────────────────────┘
```

---

## Why Not Just Call Secrets Manager Directly From the App?

This is the most important question. AWS Secrets Manager is just another AWS service
like S3 or SQS. So why not just call it directly from the app?

```
Option A: App calls Secrets Manager directly
─────────────────────────────────────────────
ums-app pod startup:
  1. app code calls AWS SDK → SecretsManager.GetSecretValue()
  2. gets JSON string back
  3. parses it manually
  4. uses values

What this costs you:

  AWS SDK in every app
  → heavier image, extra dependency to maintain, version upgrades to track

  Secret-fetching boilerplate in every app
  → Java team writes it, Node team writes it, Python team writes it
  → same 50 lines, three times, forever

  AWS Secrets Manager temporarily down?
  → app cannot start at all
  → your pod is in CrashLoopBackOff until SM recovers
  → this has happened in real production incidents

  Secret rotation (you change the DB password)?
  → app must detect the new version, re-fetch, invalidate its cache
  → handle the window where old and new password both exist
  → notoriously hard to get right without dropping connections

  New developer joins, wants to run the app locally?
  → needs AWS credentials on their laptop
  → needs correct IAM permissions
  → onboarding = half a day of AWS console work


Option B: ESO + k8s Secret  ← what we use
───────────────────────────────────────────
ESO is a controller running in the cluster.
It watches your ExternalSecret CRD.
It calls AWS SM on behalf of your app.
It creates a normal k8s Secret object.
Done.

ums-app pod startup:
  1. reads env vars — same as any 12-factor app
  2. done

What the app sees:
  POSTGRES_DB       = umsdb
  POSTGRES_USER     = umsuser
  POSTGRES_PASSWORD = ***

  The app has NO IDEA these came from AWS.
  No AWS SDK. No secret-fetching code. Zero.

What you get instead:

  App has ZERO AWS dependency
  → same image runs on AWS, GCP, Azure, local minikube
  → no AWS SDK, no boilerplate, no version drift

  AWS SM goes down?
  → k8s Secret already exists in etcd
  → app starts fine, reads what's already there
  → ESO retries in background, syncs when SM recovers

  Secret rotated?
  → ESO picks it up on next sync (every 1h, or force-trigger instantly)
  → restart the pod → picks up new value
  → no app code change needed, ever

  New developer joins?
  → kubectl create secret generic postgres-secret \
       --from-literal=POSTGRES_DB=umsdb \
       --from-literal=POSTGRES_USER=umsuser \
       --from-literal=POSTGRES_PASSWORD=localpass \
       -n ums-app
  → app runs locally. zero AWS access required.
```

**The app stays clean. AWS is an implementation detail that lives outside the app.**
This is why every serious Kubernetes setup uses ESO (or Vault Agent, or Sealed Secrets — same idea).

---

## How ESO Gets AWS Credentials (IRSA)

This is the most important concept. ESO needs AWS credentials to call Secrets Manager.
We use **IRSA (IAM Roles for Service Accounts)** — not Pod Identity.

### Why IRSA for ESO, not Pod Identity?

```
If we used Pod Identity on ESO controller:

  ESO controller pod
    │
    └─ one IAM role with access to ALL secrets
         across ALL apps, ALL namespaces        ← blast radius = entire AWS SM


With IRSA — each app gets its own scoped role:

  ESO controller (NO AWS role)
    │
    │  "use ums-app-sa token to fetch ums-app secrets"
    ▼
  ums-app-sa JWT token
    │
    ▼
  AWS STS
    │
    └─ validates JWT against OIDC provider
    │
    ▼
  ums-app-role (only has access to eks-public-dev/ums/*)
    │
    ▼
  AWS Secrets Manager → returns postgres credentials

  Blast radius if ums-app is compromised = only its own secrets ✅
```

### The IRSA Flow Step by Step

```
1. Terraform creates OIDC provider in AWS IAM
   (tells AWS: "trust JWTs signed by this EKS cluster")

2. Terraform creates ums-app-role with trust policy:
   "allow sts:AssumeRoleWithWebIdentity from
    system:serviceaccount:ums-app:ums-app-sa"

3. ums-app-sa has annotation:
   eks.amazonaws.com/role-arn: arn:aws:iam::...:role/eks-public-dev-ums-app-role

4. When ESO needs to fetch the secret:
   a. ESO calls Kubernetes: "give me a JWT for ums-app-sa"
   b. ESO reads annotation → knows which role ARN to request
   c. ESO calls AWS STS: AssumeRoleWithWebIdentity(JWT, roleArn)
   d. STS validates JWT against OIDC provider → issues temp creds
   e. ESO uses temp creds → calls Secrets Manager → gets secret
   f. ESO creates/updates postgres-secret k8s Secret object

5. postgres-0 and ums-app pods just read env vars — zero AWS awareness
```

### Why We Still Have Pod Identity Agent Addon

```
Pod Identity = best for app pods calling AWS directly

  ebs-csi-controller-sa ──Pod Identity──► EBS role ──► creates/attaches EBS volumes
  (no annotation on SA needed, agent injects creds into pod)

IRSA = best for ESO pattern (scoped per-app delegation)

Rule:
  App calls AWS directly?        → Pod Identity
  ESO fetches secret for app?    → IRSA on app's SA
```

---

## Storage: EBS CSI Driver

```
ums-app namespace
  postgres StatefulSet
    │
    └── volumeClaimTemplate: postgres-data (5Gi, ebs-gp3-sc)
           │
           ▼
    PersistentVolumeClaim
           │
           ▼  (EBS CSI driver handles this)
    PersistentVolume
           │
           ▼
    AWS EBS gp3 volume (5Gi)
           │
           └── mounted at /var/lib/postgresql/data/pgdata inside postgres-0
```

EBS CSI driver uses **Pod Identity** to get AWS permissions to create/attach EBS volumes.
The `ebs-csi-controller-sa` in `kube-system` has a Pod Identity association → `eks-public-dev-ebs-csi-role`.

---

## Kubernetes Manifests — Apply Order

```
00-namespace.yaml          creates ums-app namespace
01-storageclass.yaml       creates ebs-gp3-sc StorageClass (gp3, WaitForFirstConsumer)
02-ums-serviceaccount.yaml creates ums-app-sa with IRSA annotation
03-postgres-secret-store.yaml  tells ESO: connect to AWS SM in ap-south-1 using ums-app-sa JWT
04-postgres-externalsecret.yaml  tells ESO: fetch these 3 keys → create postgres-secret
05-postgres-configmap.yaml  POSTGRES_HOST env var for postgres init
06-postgres-statefulset.yaml  postgres-0 pod + EBS PVC
07-postgres-service.yaml   headless ClusterIP service for stable postgres-svc DNS
08-ums-configmap.yaml      DB_URL=jdbc:postgresql://postgres-svc:5432/umsdb
09-ums-deployment.yaml     2 replicas of Spring Boot UMS app
10-ums-service.yaml        LoadBalancer service → AWS ALB → public URL
```

---

## Terraform Infrastructure — What Gets Created

```
Terraform (eks-public-nodegroup/terraform/)
│
├── modules/vpc/          VPC, public/private subnets, NAT gateway
├── modules/bastion/      Bastion EC2 with SSM access (no SSH key needed)
├── modules/secrets/      AWS Secrets Manager secret (placeholder {})
└── modules/eks/
    ├── EKS cluster (Kubernetes 1.33)
    ├── Node group (2x t3.medium, public subnets)
    ├── Addons:
    │   ├── vpc-cni
    │   ├── kube-proxy
    │   ├── coredns
    │   ├── eks-pod-identity-agent   ← needed for EBS CSI
    │   ├── aws-ebs-csi-driver
    │   └── metrics-server
    ├── Pod Identity association: ebs-csi-controller-sa → ebs-csi-role
    ├── OIDC provider (for IRSA)
    ├── ums-app-role (IRSA trust: ums-app-sa → this role)
    │   └── policy: GetSecretValue on eks-public-dev/ums/postgres only
    └── EKS access entries (kubectl access for your IAM user)
```

---

## Two-Phase Secrets Pattern

Terraform creates the secret shell — no real credentials in Terraform state.
Real values seeded separately via CLI after apply.

```
Phase 1: terraform apply
  → creates AWS SM secret with value {}
  → no sensitive data in .tfstate, no interactive prompt in CI

Phase 2: seed real credentials (run once after apply)
  aws secretsmanager put-secret-value \
    --secret-id eks-public-dev/ums/postgres \
    --region ap-south-1 \
    --secret-string '{
      "POSTGRES_DB":       "umsdb",
      "POSTGRES_USER":     "umsuser",
      "POSTGRES_PASSWORD": "YourStrongPassword"
    }'

Phase 3: ESO syncs automatically
  → polls every 1h (refreshInterval in ExternalSecret)
  → or force sync: kubectl annotate externalsecret postgres-external-secret \
       -n ums-app force-sync=$(date +%s) --overwrite
```

---

## In Production: ArgoCD Replaces kubectl apply

In our local setup we run `kubectl apply -f` manually.
In production, **ArgoCD** does this automatically — GitOps.

```
LOCAL SETUP (what we did):
─────────────────────────
  You → kubectl apply -f 00-namespace.yaml
  You → kubectl apply -f 01-storageclass.yaml
  ...
  You → helm install external-secrets ...
  Manual, error-prone, not repeatable


PRODUCTION (ArgoCD):
─────────────────────────────────────────────
  Git repo
    ├── k8s-manifests/        ← your 00-10 yamls live here
    └── argocd-apps/
        ├── eso-app.yaml      ← ArgoCD Application for ESO helm chart
        └── ums-app.yaml      ← ArgoCD Application for ums manifests

  ArgoCD watches the repo every 3 minutes (default)
  Any change pushed to Git → ArgoCD detects diff → applies to cluster

  ArgoCD Application for ESO:
  ┌────────────────────────────────────────────┐
  │ apiVersion: argoproj.io/v1alpha1           │
  │ kind: Application                          │
  │ metadata:                                  │
  │   name: external-secrets                   │
  │   namespace: argocd                        │
  │ spec:                                      │
  │   source:                                  │
  │     repoURL: https://charts.external-secrets.io │
  │     chart: external-secrets               │
  │     targetRevision: 0.9.x                 │
  │   destination:                             │
  │     namespace: external-secrets            │
  │   syncPolicy:                              │
  │     automated:                             │
  │       prune: true      ← delete removed resources │
  │       selfHeal: true   ← fix manual changes       │
  └────────────────────────────────────────────┘

  Full production flow:
  ─────────────────────────────────────────────────
  Developer:
    1. writes code
    2. git push → GitHub PR → code review → merge

  ArgoCD (automatic):
    3. detects new commit in repo
    4. computes diff (desired state in git vs actual in cluster)
    5. applies diff to cluster
    6. ESO picks up new SecretStore/ExternalSecret if changed
    7. Terraform changes go through CI pipeline (GitHub Actions)

  Nobody manually touches the cluster.
  Git = source of truth.
  Cluster always matches what's in Git.
```

---

## Full End-to-End Data Flow (Running State)

```
AWS Secrets Manager
  eks-public-dev/ums/postgres
  {"POSTGRES_DB":"umsdb","POSTGRES_USER":"umsuser","POSTGRES_PASSWORD":"..."}
         │
         │ ESO polls every 1h (or on force-sync)
         │ auth: ums-app-sa JWT → STS → ums-app-role temp creds
         ▼
  postgres-secret (k8s Secret in ums-app namespace)
  POSTGRES_DB=umsdb
  POSTGRES_USER=umsuser
  POSTGRES_PASSWORD=...
         │
         ├──────────────────────────────────────────┐
         ▼                                          ▼
  postgres-0 (StatefulSet)                  ums-app pods (x2)
  image: postgres:16-alpine                 image: spring boot app
  data: EBS gp3 volume (/pgdata)            connects to postgres-svc:5432
  listens on :5432                          exposes REST API on :8080
         │                                          │
         └──────── postgres-svc (headless) ─────────┘
                                                    │
                                              ums-svc (LoadBalancer)
                                                    │
                                             AWS NLB/ALB
                                                    │
                                             Internet → your browser
```
