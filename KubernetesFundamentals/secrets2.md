# Kubernetes Secrets Management — Complete Guide
> A complete guide from primitive on-prem secrets to production-grade ESO and CSI Driver architectures on EKS. Includes deep-dive on storage architecture, security analysis, and real-world production decision frameworks.

---

## Table of Contents

1. [Primitive On-Prem Kubernetes Secrets](#1-primitive-on-prem-kubernetes-secrets)
   - 1.1 [What is a Kubernetes Secret?](#11-what-is-a-kubernetes-secret)
   - 1.2 [ConfigMap vs Secret vs StorageClass](#12-configmap-vs-secret-vs-storageclass)
   - 1.3 [Problems with Native Secrets](#13-problems-with-native-secrets)
2. [Where Secrets Actually Live — Storage Architecture Deep Dive](#2-where-secrets-actually-live--storage-architecture-deep-dive)
   - 2.1 [etcd: The Single Persistent Store in Kubernetes](#21-etcd-the-single-persistent-store-in-kubernetes)
   - 2.2 [How Secrets Reach Your Pod — The Kubelet Mechanisms](#22-how-secrets-reach-your-pod--the-kubelet-mechanisms)
   - 2.3 [What tmpfs Is and Where the RAM Comes From](#23-what-tmpfs-is-and-where-the-ram-comes-from)
   - 2.4 [What CSI Actually Means — Not a Storage Type](#24-what-csi-actually-means--not-a-storage-type)
   - 2.5 [When to Use EFS — And When Not To](#25-when-to-use-efs--and-when-not-to)
3. [External Secrets Operator (ESO)](#3-external-secrets-operator-eso)
   - 3.1 [How ESO Works](#31-how-eso-works)
   - 3.2 [SecretStore and ExternalSecret Manifests](#32-secretstore-and-externalsecret-manifests)
   - 3.3 [IRSA vs Pod Identity Agent with ESO](#33-irsa-vs-pod-identity-agent-with-eso)
4. [Secrets Store CSI Driver + ASCP](#4-secrets-store-csi-driver--ascp)
   - 4.1 [How CSI Driver + ASCP Works](#41-how-csi-driver--ascp-works)
   - 4.2 [Full Storage-Level Flow at Pod Startup](#42-full-storage-level-flow-at-pod-startup)
   - 4.3 [SecretProviderClass Manifest](#43-secretproviderclass-manifest)
   - 4.4 [IRSA vs Pod Identity Agent with CSI](#44-irsa-vs-pod-identity-agent-with-csi)
5. [Security Analysis — Attack Surface Comparison](#5-security-analysis--attack-surface-comparison)
   - 5.1 [etcd vs RAM: Full Threat Model](#51-etcd-vs-ram-full-threat-model)
   - 5.2 [Attack Difficulty: Step-by-Step](#52-attack-difficulty-step-by-step)
   - 5.3 [Additional RAM Hardening Options](#53-additional-ram-hardening-options)
6. [ESO vs CSI Driver — Full Comparison](#6-eso-vs-csi-driver--full-comparison)
   - 6.1 [Feature Comparison Table](#61-feature-comparison-table)
   - 6.2 [Where Does the Secret Value Live?](#62-where-does-the-secret-value-live)
   - 6.3 [Production Decision Framework](#63-production-decision-framework)
   - 6.4 [Real Example: Redis and ElastiCache](#64-real-example-redis-and-elasticache)
   - 6.5 [Decision Tree](#65-decision-tree)
7. [Production Architecture — ArgoCD + ESO + AWS](#7-production-architecture--argocd--eso--aws)

---

## 1. Primitive On-Prem Kubernetes Secrets

Before understanding modern secret management, you need to understand what Kubernetes offers natively and why it is not enough for production.

### 1.1 What is a Kubernetes Secret?

A Kubernetes Secret is a native object that stores sensitive data like passwords, tokens, and keys. It is separate from a Pod so that sensitive data is not hardcoded into Pod specs. Kubernetes stores secrets in **etcd** — its internal key-value database.

**IMPORTANT:** Kubernetes Secrets are only base64-encoded, NOT encrypted.
`base64 != encryption`. Anyone with `kubectl get secret -o yaml` access can decode them instantly.

```
Basic Kubernetes Secret Flow
────────────────────────────────────────────────────────────────────────────────────────────────────────

Developer ───(kubectl apply)───▶ K8s API Server ───(writes to) ──────────────┐
                                                                              ▼
                                                                             etcd 
                                                           (Secret: db-secret | base64 encoded)
                                                                              │
                                                                              │ (mounted into)
                                                                              ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                 Pod                                                    │
├───────────────────────────────────────────────┬────────────────────────────────────────────────────────┤
│             Option A: ENV VAR                 │                Option B: File Mount                    │
│ env:                                          │ volumeMounts:                                          │
│   - name: DB_PASSWORD                         │   - mountPath: /etc/secrets                            │
│     valueFrom:                                │     name: secret-vol                                   │
│       secretKeyRef: {name: db-secret, key: pw}│                                                        │
└───────────────────────────────────────────────┴────────────────────────────────────────────────────────┘
```

---

### 1.2 ConfigMap vs Secret vs StorageClass

These three are often confused. They serve completely different purposes and are **NOT** all used together for secrets management.

```
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│      ConfigMap       │   │        Secret        │   │    StorageClass      │
│──────────────────────│   │──────────────────────│   │──────────────────────│
│  Non-sensitive data  │   │  Sensitive data      │   │  Disk provisioning   │
│                      │   │                      │   │                      │
│  Examples:           │   │  Examples:           │   │  Examples:           │
│   - App config       │   │   - Passwords        │   │   - AWS EBS          │
│   - Port numbers     │   │   - API keys         │   │   - AWS EFS          │
│   - Log levels       │   │   - TLS certs        │   │   - GCP PD           │
│   - Feature flags    │   │   - OAuth tokens     │   │                      │
│   - ENV=production   │   │   - SSH keys         │   │  Used for:           │
│                      │   │                      │   │   - Databases        │
│  Stored as:          │   │  Stored as:          │   │   - Stateful apps    │
│   plaintext in etcd  │   │   base64 in etcd     │   │   - PVC provisioning │
│                      │   │                      │   │                      │
│  Safe to commit?     │   │  Safe to commit?     │   │  UNRELATED to        │
│   YES (usually)      │   │   NEVER              │   │  secrets entirely    │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘

NOTE: StorageClass has NOTHING to do with secrets management.
      It is only used when apps need persistent disk (like a database).
```

---

### 1.3 Problems with Native Secrets

**Problem 1 — Hardcoding in Deployment YAML**

```yaml
# NEVER DO THIS
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - env:
            - name: DB_PASSWORD
              value: "mysecretpassword123"   # visible in Git forever
```

```
Problems:
─────────
❌ Secret visible in Git history (even if deleted later)
❌ Anyone with repo access can read it
❌ Impossible to rotate without editing YAML and redeploying
❌ Different value per environment = multiple manual files
```

**Problem 2 — Multi-Cluster Manual Sync**

```
         One secret must exist in every cluster
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   ┌──────────┐   ┌──────────┐   ┌──────────┐
   │   Dev    │   │  Stage   │   │   Prod   │
   │ Cluster  │   │ Cluster  │   │ Cluster  │
   │──────────│   │──────────│   │──────────│
   │ kubectl  │   │ kubectl  │   │ kubectl  │
   │  create  │   │  create  │   │  create  │
   │  secret  │   │  secret  │   │  secret  │
   └──────────┘   └──────────┘   └──────────┘

Problems:
─────────
❌ Must update every cluster manually on rotation
❌ Clusters drift — dev has old value, prod has new
❌ No audit trail of who changed what when
❌ Human error on rotation = production outage
```

---

## 2. Where Secrets Actually Live — Storage Architecture Deep Dive

This section answers a fundamental question that everything else depends on: **where exactly does a secret value sit on disk, in memory, or in the network at each stage?** Understanding this is the key to understanding WHY ESO and CSI Driver exist, and what threat each one prevents.

### 2.1 etcd: The Single Persistent Store in Kubernetes

etcd is a key-value database that runs as a pod on the control plane node. It is the **only** persistent storage in Kubernetes. Everything in Kubernetes — pods, deployments, services, secrets — is just a record in etcd.

```
┌─────────────────────────────────────────────────────────────────┐
│  KUBERNETES STORAGE ARCHITECTURE                                │
│                                                                 │
│  When ESO (or kubectl) creates a K8s Secret:                   │
│                                                                 │
│  ESO → kube-apiserver → etcd                                   │
│                                                                 │
│  The Secret is stored in etcd exactly like this:               │
│                                                                 │
│  key:   /registry/secrets/my-namespace/db-secret               │
│  value: {                                                       │
│           "kind": "Secret",                                     │
│           "data": {                                             │
│             "password": "aHVudGVyMg=="   ← base64, NOT encrypted│
│           }                                                     │
│         }                                                       │
│                                                                 │
│  etcd writes this record to DISK on the control plane node.    │
│  On EKS, AWS manages this disk — you never see it.             │
│  It is an AWS-managed EBS volume attached to the control plane. │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

The full persistence chain when using ESO or native secrets:

```text
ESO Pod ──(writes Secret)──▶ kube-apiserver ──(persists to)──▶ etcd (KV Store) ──(writes to)──▶ EBS (EKS Managed)
[In-Cluster]                [Control Plane]                     [Control Plane]                  [AWS Infrastructure]

(on EKS: AWS-managed EBS volume you never touch)
```

**Why this matters:** The secret value is now on a disk, inside a K8s object, readable by anyone with the right RBAC. This is the risk that CSI Driver was built to eliminate.

---

### 2.2 How Secrets Reach Your Pod — The Kubelet Mechanisms

After a secret exists in etcd, a separate mechanism delivers it into your pod. The **kubelet** (the agent running on every worker node) handles this. There are two paths:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                              HOW A SECRET REACHES YOUR POD                                             │
├────────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────┤
│ PATH 1: Environment Variable                               │ PATH 2: Volume Mount                                      │
├────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────┤
│ 1. Kubelet fetches Secret from API Server                  │ 1. Kubelet fetches Secret from API Server                 │
│ 2. Injected as ENV at Pod startup                          │ 2. Kubelet creates a tmpfs mount inside Pod               │
│ 3. Lives in PROCESS MEMORY of container                    │ 3. Writes Secret as a FILE on that tmpfs                  │
│ 4. Gone when Pod dies                                      │ 4. App reads file (e.g., /etc/secrets/password)           │
│                                                            │ 5. Gone when Pod dies                                     │
├────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────┤
│  IMPORTANT: Both paths are EPHEMERAL. tmpfs = RAM, not disk. No EBS/EFS/Physical storage is used on the Node.          │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Visual chain from etcd to pod:

```
etcd (control plane disk)
  │
  │  kubelet reads secret value via API on pod startup
  ▼
Node RAM (worker node where pod runs)
  │
  ├── PATH 1 — env var:
  │     injected into container process environment
  │     lives in process memory
  │     never on disk
  │
  └── PATH 2 — volume mount:
        tmpfs created in pod's filesystem
        /etc/secrets/password  ← file in RAM
        disappears when pod dies
        never touches node disk
        never touches EFS or EBS
```

**The key insight:** Even with native K8s Secrets (or ESO), the secret ALWAYS passes through etcd first. The tmpfs on the pod is only the delivery mechanism into the pod — the secret still lives in etcd persistently. With CSI Driver, the secret skips etcd entirely and goes directly into tmpfs.

---

### 2.3 What tmpfs Is and Where the RAM Comes From

A common question: where does this RAM come from? The answer is straightforward — it comes from the EC2 instance you chose as your worker node.

```
┌─────────────────────────────────────────────────────────────────┐
│  EC2 INSTANCE = CPU + RAM + DISK                                │
│                                                                 │
│  When you pick an instance type like t3.medium:                 │
│                                                                 │
│    t3.medium                                                    │
│    ├── 2 vCPU                                                   │
│    ├── 4 GB RAM        ← this is where tmpfs lives              │
│    └── disk (EBS)      ← this is separate, persistent           │
│                                                                 │
│  You DO choose RAM — implicitly, by picking the instance type.  │
│                                                                 │
│  t3.micro   = 1 GB RAM                                          │
│  t3.medium  = 4 GB RAM                                          │
│  m5.large   = 8 GB RAM                                          │
│  m5.xlarge  = 16 GB RAM                                         │
│  r5.2xlarge = 64 GB RAM  (r-series = memory-optimized)          │
│                                                                 │
│  The disk size you configure separately in EKS node groups is   │
│  the EBS volume — completely different from RAM.                │
└─────────────────────────────────────────────────────────────────┘
```

How RAM is divided on a live worker node:

```
┌──────────────────────────────────────────────────────────┐
│  Worker Node (e.g., m5.large — 8 GB RAM)                 │
│                                                          │
│  RAM (8 GB total):                                       │
│    ├── OS kernel:           ~200 MB                      │
│    ├── kubelet + kube-proxy: ~200 MB                     │
│    ├── Pod A (your app):    ~512 MB                      │
│    │     └── tmpfs secret:  ~1 KB   ← negligible         │
│    ├── Pod B (your app):    ~512 MB                      │
│    │     └── tmpfs secret:  ~1 KB   ← negligible         │
│    ├── DaemonSets:          ~300 MB                      │
│    └── remaining free RAM                                │
│                                                          │
│  EBS Disk (e.g., 50 GB):                                 │
│    ├── OS                                                │
│    ├── container images                                  │
│    ├── logs                                              │
│    └── secrets NEVER here                                │
└──────────────────────────────────────────────────────────┘
```

A secret is a few hundred bytes to a few kilobytes. It occupies effectively zero RAM. You will never run out of memory because of secrets in tmpfs.

```
Normal Filesystem (EBS disk):              tmpfs (RAM-based):
─────────────────────────────              ─────────────────────────────────
Data written to → EBS disk                 Data written to → RAM only
Survives pod restart  ✅                   Pod deleted   → gone  ✅ secure
Survives node restart ✅                   Node restart  → gone  ✅ secure
Visible on disk       ✅                   Not on disk         ✅ secure
etcd involved         ✅                   etcd NOT involved   ✅ secure
```

---

### 2.4 What CSI Actually Means — Not a Storage Type

**The most common misconception:** "CSI Driver = EFS or EBS." This is wrong. CSI is a standard, not a storage type.

```
┌─────────────────────────────────────────────────────────────────┐
│  CSI = Container Storage Interface                              │
│                                                                 │
│  CSI is a STANDARD / PROTOCOL — not a specific storage system. │
│                                                                 │
│  Kubernetes uses CSI to talk to ANY storage backend:            │
│    - AWS EBS  (block storage)        ← uses CSI driver          │
│    - AWS EFS  (file storage)         ← uses CSI driver          │
│    - Secrets Store (tmpfs injection) ← ALSO uses CSI driver     │
│                                                                 │
│  Just because something uses the CSI interface does NOT mean   │
│  it stores data on EFS or EBS.                                 │
│                                                                 │
│  The Secrets Store CSI Driver uses CSI purely as the mechanism │
│  to mount something into a pod's filesystem.                   │
│  What it mounts is tmpfs (RAM). Not EFS. Not EBS.              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Comparison of two drivers that both use the CSI interface:

```
┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│  EFS CSI Driver                  │  │  Secrets Store CSI Driver + ASCP │
│                                  │  │                                  │
│  What it mounts: EFS filesystem  │  │  What it mounts: tmpfs (RAM)     │
│  Data lives on:  AWS EFS disk    │  │  Data lives on:  nowhere on disk  │
│  Persists when pod dies: YES     │  │  Persists when pod dies: NO      │
│  Used for: databases, file share │  │  Used for: secrets injection     │
│  Data source: EFS volume         │  │  Data source: AWS Secrets Manager│
│                                  │  │               (fetched at runtime)│
└──────────────────────────────────┘  └──────────────────────────────────┘
         same CSI interface                    same CSI interface
         different backing storage             different backing storage
```

---

### 2.5 When to Use EFS — And When Not To

EFS is for a completely different use case. Mixing it up with secrets management is a category error.

```
USE EFS when:
─────────────
  ✅ Your app writes files that must survive pod death
  ✅ Multiple pods need to read/write the same files simultaneously
  ✅ Examples: uploaded user files, ML model weights, shared logs,
              database files for stateful workloads

NEVER use EFS for:
───────────────────
  ❌ Secrets   → use ESO or CSI + ASCP
  ❌ Config    → use ConfigMap
  ❌ Anything that should be ephemeral or transient

The one-line rule:
──────────────────────────────────────────────────────────
EFS / EBS  =  persistent data your APP produces or shares
tmpfs      =  temporary sensitive data injected at runtime,
              gone when pod dies
etcd       =  Kubernetes object state (managed by K8s, not you)
```

---

## 3. External Secrets Operator (ESO)

**What ESO solves:** Centralized secret management. AWS Secrets Manager becomes the single source of truth. ESO automatically syncs secrets into Kubernetes. You never write secret values in Git or kubectl commands.

**What ESO does NOT solve:** Secrets still end up in Kubernetes etcd as a `kind: Secret` object. `kubectl get secret -o yaml` still shows base64-encoded values. If you need secrets to never touch etcd, use CSI Driver (Section 4).

---

### 3.1 How ESO Works

```
┌──────────────────────────────────────────────────────────────────────┐
│                           AWS Layer                                  │
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │                  AWS Secrets Manager                         │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │   /prod/myapp/db-password  = "hunter2"                       │  │
│   │   /prod/myapp/api-key      = "sk-abc123"                     │  │
│   └──────────────────────────┬───────────────────────────────────┘  │
│                              │  GetSecretValue (IAM authenticated)  │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────────┐
│  EKS Cluster                 │                                      │
│                              ▼                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  namespace: external-secrets                                 │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │  ┌────────────────────────────────────────────────────────┐  │  │
│   │  │  ESO Controller Pod                                    │  │  │
│   │  │────────────────────────────────────────────────────────│  │  │
│   │  │  - Watches ExternalSecret CRDs cluster-wide            │  │  │
│   │  │  - Polls AWS every refreshInterval                     │  │  │
│   │  │  - Creates / updates K8s Secrets automatically         │  │  │
│   │  └────────────────────────────────────────────────────────┘  │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│                              │  ESO reads ExternalSecret CRD        │
│                              ▼                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  namespace: my-app                                           │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │                                                              │  │
│   │  ┌──────────────────────────┐                               │  │
│   │  │     ExternalSecret       │  ← YOU write this (safe Git)  │  │
│   │  │──────────────────────────│                               │  │
│   │  │  fetch: /prod/myapp/db   │                               │  │
│   │  │  create: db-secret       │                               │  │
│   │  └─────────────┬────────────┘                               │  │
│   │                │  ESO auto-creates                          │  │
│   │  ┌─────────────▼────────────┐                               │  │
│   │  │   kind: Secret (K8s)     │  ← ESO creates, you never     │  │
│   │  │──────────────────────────│    touch this manually        │  │
│   │  │   password: aHVudGVyMg== │                               │  │
│   │  └─────────────┬────────────┘                               │  │
│   │                │                                            │  │
│   │  ┌─────────────▼────────────┐                               │  │
│   │  │   Application Pod        │                               │  │
│   │  │──────────────────────────│                               │  │
│   │  │   env: DB_PASSWORD       │                               │  │
│   │  │   (reads K8s Secret,     │                               │  │
│   │  │    no AWS awareness)     │                               │  │
│   │  └──────────────────────────┘                               │  │
│   └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 SecretStore and ExternalSecret — What Are They?

ESO uses two custom resources. Think of them as two separate questions that must both be answered:

```
┌──────────────────────────────────────────────────────────────────────┐
│  ClusterSecretStore                                                  │
│──────────────────────────────────────────────────────────────────────│
│  Question answered: "HOW do I connect to AWS?"                       │
│                                                                      │
│  Contains:                                                           │
│   - Which backend? (AWS Secrets Manager / SSM / Vault)               │
│   - Which region?                                                    │
│   - Which IAM identity to use?                                       │
│   - Which namespaces are allowed to use this store?                  │
│                                                                      │
│  Scope: Cluster-wide with optional namespaceSelector to restrict     │
└──────────────────────────────────────────────────────────────────────┘
                              │  referenced by
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  ExternalSecret                                                      │
│──────────────────────────────────────────────────────────────────────│
│  Question answered: "WHICH secret do I want?"                        │
│                                                                      │
│  Contains:                                                           │
│   - Which ClusterSecretStore to use?                                 │
│   - Which AWS secret path to fetch?                                  │
│   - What to name the resulting K8s Secret?                           │
│   - How often to refresh?                                            │
│                                                                      │
│  Scope: Namespace-scoped (lives in the app's namespace)              │
└──────────────────────────────────────────────────────────────────────┘
                              │  ESO creates
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  kind: Secret (auto-generated by ESO — you never write this)         │
│──────────────────────────────────────────────────────────────────────│
│  name: db-secret                                                     │
│  data:                                                               │
│    password: aHVudGVyMg==   ← base64("hunter2")                      │
└──────────────────────────────────────────────────────────────────────┘
```

**ClusterSecretStore YAML:**

```yaml
# cluster-secret-store.yaml — safe to commit to Git
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: eso-sa             # SA with IAM identity
            namespace: external-secrets
  conditions:
    - namespaceSelector:             # optional: restrict namespaces
        matchLabels:
          my-org/secret-store: teamone-secret-store
```

**ExternalSecret YAML:**

```yaml
# external-secret.yaml — safe to commit to Git (no secret values)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: my-app
spec:
  refreshInterval: 1h              # ESO re-syncs from AWS every hour
  secretStoreRef:
    name: aws-secrets-manager      # points to ClusterSecretStore above
    kind: ClusterSecretStore
  target:
    name: db-secret                # K8s Secret ESO will create
    creationPolicy: Owner
  data:
    - secretKey: password          # key in the resulting K8s Secret
      remoteRef:
        key: prod/myapp/db         # path in AWS Secrets Manager
        property: password         # field inside the JSON secret
```

**Multi-Team Namespace Isolation:**

```
                    ┌──────────────────────────────────────────┐
                    │          ClusterSecretStore              │
                    │──────────────────────────────────────────│
                    │  name: teamone-ssm                       │
                    │  provider: AWS SSM                       │
                    │                                          │
                    │  namespaceSelector:                      │
                    │    matchLabels:                          │
                    │      my-org/secret-store:                │
                    │        teamone-secret-store              │
                    └─────────────────┬────────────────────────┘
                                      │
                     namespaceSelector checks namespace label
                                      │
              ┌───────────────────────┴──────────────────────────┐
              │                                                  │
              ▼                                                  ▼
   ALLOWED                                             REJECTED

┌──────────────────────────────┐       ┌──────────────────────────────┐
│  Namespace: teamone-db       │       │  Namespace: teamtwo-db       │
│──────────────────────────────│       │──────────────────────────────│
│  labels:                     │       │  labels:                     │
│    my-org/secret-store:      │       │    my-org/secret-store:      │
│      teamone-secret-store    │       │      teamtwo-secret-store    │
│      matches selector ✅     │       │      no match ❌             │
│                              │       │                              │
│  ┌──────────────────────┐    │       │  ┌──────────────────────┐   │
│  │   ExternalSecret     │    │       │  │   ExternalSecret     │   │
│  │  secretStoreRef:     │    │       │  │  secretStoreRef:     │   │
│  │    teamone-ssm       │    │       │  │    teamone-ssm       │   │
│  └──────────┬───────────┘    │       │  └──────────┬───────────┘   │
└─────────────┼────────────────┘       └─────────────┼───────────────┘
              │                                       │
              ▼                                       ▼
     K8s Secret created ✅               ESO rejects request ❌
                                     "namespace label mismatch"
```

---

### 3.3 IRSA vs Pod Identity Agent with ESO

ESO needs an AWS IAM identity to call AWS Secrets Manager. There are two ways to give it one. Both achieve the same result — only the configuration method differs.

```
IRSA — IAM Roles for Service Accounts             [older approach]
──────────────────────────────────────────────────────────────────────

  Step 1: Configure OIDC provider on EKS cluster (manual setup)
  Step 2: Create IAM Role with trust policy pointing to OIDC
  Step 3: Add annotation to ServiceAccount YAML:

  ┌──────────────────────────────────────────────────────────────┐
  │  kind: ServiceAccount                                        │
  │  metadata:                                                   │
  │    name: eso-sa                                              │
  │    namespace: external-secrets                               │
  │    annotations:                                              │
  │      eks.amazonaws.com/role-arn:                             │
  │        arn:aws:iam::123456:role/eso-reader    ← annotation   │
  └──────────────────────────────────────────────────────────────┘

  Flow:
  ESO Pod → OIDC token → STS AssumeRoleWithWebIdentity
          → IAM Role credentials → AWS SM API call


EKS Pod Identity Agent                    [recommended for EKS today]
──────────────────────────────────────────────────────────────────────

  Step 1: Enable Pod Identity Agent addon on EKS
  Step 2: Create PodIdentityAssociation in AWS (NOT in K8s YAML):

  aws eks create-pod-identity-association \
    --cluster-name vbl-eks-shared \
    --namespace external-secrets \
    --service-account eso-sa \
    --role-arn arn:aws:iam::123456:role/eso-reader

  Step 3: ServiceAccount YAML has NO annotation:

  ┌──────────────────────────────────────────────────────────────┐
  │  kind: ServiceAccount                                        │
  │  metadata:                                                   │
  │    name: eso-sa                                              │
  │    namespace: external-secrets                               │
  │    # no annotation needed — clean YAML                       │
  └──────────────────────────────────────────────────────────────┘

  Flow:
  ESO Pod → Pod Identity Agent (daemonset on node)
          → IAM Role credentials → AWS SM API call


Comparison:
──────────────────────────────────────────────────────────────────────
  Feature                      IRSA              Pod Identity Agent
  ────────────────────────────────────────────────────────────────────
  Annotation in YAML?          YES               NO
  OIDC provider setup?         YES (manual)      NO (EKS manages)
  Works on non-EKS?            YES               NO (EKS only)
  Recommended for EKS today?   No                YES
  K8s manifest has AWS ARN?    YES               NO (cleaner GitOps)
```

**IAM Policy for ESO:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-2:123456:secret:prod/*"
    }
  ]
}
```

```bash
# One-liner to create the policy:
aws iam create-policy \
  --policy-name ESOReadPolicy \
  --policy-document file://eso-policy.json
```

> **Production combination for ESO:**
> `ESO + EKS Pod Identity Agent + ClusterSecretStore + ExternalSecret + ArgoCD`
> Pod Identity is preferred over IRSA on EKS — no annotation in manifests, cleaner GitOps.

---

## 4. Secrets Store CSI Driver + ASCP

**What this solves that ESO cannot:** Secrets never enter Kubernetes etcd. They are mounted directly into the pod filesystem from AWS Secrets Manager at pod startup using an in-memory `tmpfs` volume. `kubectl get secret` shows nothing.

Two components work together:

```
Secrets Store CSI Driver
└── Generic Kubernetes framework
└── Implements Container Storage Interface (a standard — see Section 2.4)
└── Mounts secrets as files into pods
└── Does NOT know how to talk to AWS by itself

ASCP (AWS Secrets and Configuration Provider)
└── AWS-specific plugin for the CSI Driver
└── Knows how to auth to AWS and fetch secrets
└── Without ASCP, CSI Driver cannot talk to AWS

CSI Driver alone  =  incomplete
CSI Driver + ASCP =  complete solution
```

---

### 4.1 How CSI Driver + ASCP Works

```
┌──────────────────────────────────────────────────────────────────────┐
│                           AWS Layer                                  │
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │                  AWS Secrets Manager                         │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │   /prod/myapp/db-password  = "hunter2"                       │  │
│   └──────────────────────────┬───────────────────────────────────┘  │
│                              │  ASCP fetches on pod startup         │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────────┐
│  EKS Cluster — Pod scheduled on a Node                               │
│                              │                                      │
│  Kubelet detects pod needs a CSI volume                             │
│                              ▼                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  CSI Driver (DaemonSet running on every node)                │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │  "Pod needs a secrets-store volume, delegate to provider"    │  │
│   └──────────────────────────┬───────────────────────────────────┘  │
│                              │  calls provider                      │
│                              ▼                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  ASCP — AWS Provider Plugin                                  │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │  1. Uses Pod Identity / IRSA for IAM auth                    │  │
│   │  2. Calls AWS SM GetSecretValue API                           │  │
│   │  3. Returns secret value to CSI Driver                        │  │
│   └──────────────────────────┬───────────────────────────────────┘  │
│                              │  value returned                      │
│                              ▼                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  tmpfs mount (RAM-based in-memory filesystem)                │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │  ✅ Lives in NODE RAM only                                   │  │
│   │  ✅ NOT written to disk                                      │  │
│   │  ✅ NOT stored in etcd                                       │  │
│   │  ✅ NOT visible via kubectl get secret                       │  │
│   │  ✅ Pod deleted → RAM wiped → secret gone                    │  │
│   └──────────────────────────┬───────────────────────────────────┘  │
│                              │  mounted into pod                    │
│                              ▼                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  Application Pod                                             │  │
│   │──────────────────────────────────────────────────────────────│  │
│   │  /mnt/secrets-store/                                         │  │
│   │  └── db-password    ← app reads this as a regular file       │  │
│   └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘

What does NOT happen:
─────────────────────
❌ No K8s Secret object created
❌ No etcd write
❌ kubectl get secret → nothing to see

What DOES happen:
─────────────────
✅ Secret fetched fresh on every pod startup
✅ Stored in RAM only (tmpfs on worker node EC2 RAM)
✅ Pod deleted → RAM wiped → secret gone
```

**The secretObjects Twist:**

```
WITHOUT secretObjects    ← pure CSI, no etcd
────────────────────────────────────────────────────────────────────
AWS SM → ASCP → CSI → tmpfs → Pod file mount only
etcd: NOT touched
kubectl get secret: nothing visible


WITH secretObjects       ← hybrid mode, same as ESO behavior
────────────────────────────────────────────────────────────────────
AWS SM → ASCP → CSI → tmpfs → Pod file mount
                    ↓
              ALSO creates K8s Secret → etcd written → kubectl visible


WHY enable secretObjects?
─────────────────────────
Some apps only support env vars:

  env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:    ← requires a K8s Secret to exist
          name: db-secret

  If your app cannot read files from /mnt/secrets-store/
  then you enable secretObjects for compatibility.
```

---

### 4.2 Full Storage-Level Flow at Pod Startup

This is the precise sequence of what happens at the storage level when a pod using CSI + ASCP starts:

```
Pod scheduled on Node
  │
  │  kubelet says: "this pod needs a CSI volume"
  ▼
Secrets Store CSI Driver (DaemonSet on every worker node)
  │
  │  calls ASCP (AWS provider plugin)
  ▼
ASCP authenticates via Pod Identity / IRSA
  │
  │  calls AWS Secrets Manager: GetSecretValue
  ▼
AWS Secrets Manager returns: "hunter2"
  │
  │  ASCP hands value back to CSI Driver
  ▼
CSI Driver creates tmpfs mount
  │
  │  tmpfs = memory-only filesystem carved out of node RAM
  │  mounts it at /mnt/secrets-store/ inside the pod
  ▼
Secret written as a FILE into that tmpfs:
  /mnt/secrets-store/db-password  → contains "hunter2"
  │
  │  lives only in node RAM (EC2 instance RAM)
  │  never touches any disk (not EBS, not EFS, not node disk)
  │  not visible in etcd
  │  disappears when pod is terminated
  ▼
App reads it like a normal file:
  password = open("/mnt/secrets-store/db-password").read()
```

---

### 4.3 SecretProviderClass Manifest

This is the CSI equivalent of ExternalSecret in ESO.

```yaml
# secret-provider-class.yaml — safe to commit to Git
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: db-credentials
  namespace: my-app
spec:
  provider: aws                          # use ASCP (AWS provider)
  parameters:
    objects: |
      - objectName: "prod/myapp/db"      # AWS Secrets Manager path
        objectType: "secretsmanager"
        objectAlias: "db-password"       # filename inside the pod

  # secretObjects is OPTIONAL
  # Remove this block for pure CSI (no etcd storage)
  secretObjects:
    - secretName: db-secret
      type: Opaque
      data:
        - objectName: db-password
          key: password
```

**Pod Spec for CSI:**

```yaml
# deployment.yaml
spec:
  serviceAccountName: my-app-sa          # this SA needs IAM identity
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: db-credentials
  containers:
    - name: my-app
      volumeMounts:
        - name: secrets-store
          mountPath: /mnt/secrets-store
          readOnly: true
      # App reads: cat /mnt/secrets-store/db-password
```

---

### 4.4 IRSA vs Pod Identity Agent with CSI

```
WITH IRSA:
──────────────────────────────────────────────────────────────────────
  App Pod (ServiceAccount: my-app-sa)
    │  SA has annotation in YAML:
    │  eks.amazonaws.com/role-arn: arn:aws:iam::123:role/app-role
    ▼
  ASCP reads pod's projected service account token
    ▼
  STS: AssumeRoleWithWebIdentity → IAM Role credentials
    ▼
  ASCP calls AWS Secrets Manager → secret fetched → mounted


WITH EKS Pod Identity Agent (recommended):
──────────────────────────────────────────────────────────────────────
  App Pod (ServiceAccount: my-app-sa)
    │  SA has NO annotation (clean YAML)
    ▼
  ASCP → Pod Identity Agent (DaemonSet on node)
    ▼
  Pod Identity Agent exchanges token → IAM Role credentials
    ▼
  ASCP calls AWS Secrets Manager → secret fetched → mounted


CRITICAL DIFFERENCE FROM ESO:
──────────────────────────────────────────────────────────────────────
  With ESO:   Only the ESO controller pod needs IAM identity.
              App pods do NOT need AWS credentials at all.

  With CSI:   The APP POD itself needs IAM identity because ASCP
              fetches the secret in the context of that pod.
              Each application SA needs its own IAM role.
```

**IAM Policy for CSI + ASCP:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-2:123456:secret:prod/myapp/*"
    }
  ]
}
```

```bash
# One-liner pod identity association for the app pod's SA:
aws eks create-pod-identity-association \
  --cluster-name vbl-eks-prod \
  --namespace my-app \
  --service-account my-app-sa \
  --role-arn arn:aws:iam::123456:role/myapp-secrets-reader
```

> **Production combination for CSI:**
> `CSI Driver + ASCP + EKS Pod Identity Agent + SecretProviderClass`
> Used in compliance-heavy environments (PCI-DSS, HIPAA) where secrets must never touch etcd.

---

## 5. Security Analysis — Attack Surface Comparison

### 5.1 etcd vs RAM: Full Threat Model

RAM is not perfectly safe — but it is dramatically harder to exploit than etcd. Understanding the precise threat model is what should drive your choice between ESO and CSI.

```
┌─────────────────────────────────────────────────────────────────┐
│  ATTACK SURFACE COMPARISON                                      │
├──────────────────────────────┬──────────────────────────────────┤
│  etcd (ESO approach)         │  tmpfs RAM (CSI approach)        │
├──────────────────────────────┼──────────────────────────────────┤
│                              │                                  │
│  Persists forever on disk    │  Exists only while pod runs      │
│                              │                                  │
│  Accessible via:             │  Accessible via:                 │
│  - kubectl get secret        │  - physical memory access        │
│  - any pod with RBAC access  │  - /proc/PID/mem (kernel level)  │
│  - etcd backup files         │  - hypervisor escape (rare)      │
│  - etcd snapshot             │  - node compromise + memory dump │
│  - etcd disk breach          │                                  │
│                              │                                  │
│  Survives pod death: YES     │  Survives pod death: NO          │
│  Survives node reboot: YES   │  Survives node reboot: NO        │
│  Shows in kubectl: YES       │  Shows in kubectl: NO            │
│  In backups: YES             │  In backups: NO                  │
│                              │                                  │
└──────────────────────────────┴──────────────────────────────────┘
```

---

### 5.2 Attack Difficulty: Step-by-Step

```
To steal a secret from etcd (ESO approach):
────────────────────────────────────────────
  Step 1: Get kubectl access with get secret RBAC permission
          — or breach the control plane disk
          — or access an etcd backup
  Step 1 is ENOUGH.
  Secret is sitting there as a K8s object.
  Base64-decode it: echo "aHVudGVyMg==" | base64 -d
  → hunter2
  It also lives in every etcd backup ever taken.


To steal a secret from tmpfs RAM (CSI approach):
─────────────────────────────────────────────────
  Step 1: Compromise the worker node completely (get root access)
  Step 2: Find the correct container process ID
  Step 3: Read /proc/PID/mem or execute a full memory dump
  Step 4: Parse raw memory to locate and extract the secret
  All 4 steps required. Each step is significantly harder than the last.
  Attack window is limited — secret disappears when pod dies.


Why compliance frameworks (PCI-DSS, HIPAA, SOC2, FedRAMP) prefer CSI:
───────────────────────────────────────────────────────────────────────
  Smaller attack surface
  Shorter window of exposure
  No persistent copy on any disk
  Not included in cluster backups
  kubectl audit log shows nothing for the secret
```

---

### 5.3 Additional RAM Hardening Options

For environments that need to go even further:

```
Additional hardening layers for tmpfs secrets:
────────────────────────────────────────────────
  - Enable memory encryption on EC2
      AMD SEV (Secure Encrypted Virtualization)
      AWS Nitro Enclaves for most sensitive workloads

  - Use Kubernetes memory limits to isolate pod RAM
      Prevents one pod from reading another pod's memory

  - Linux namespace isolation
      Already default in Kubernetes — each pod has its own
      mount namespace, so /mnt/secrets-store is not visible
      from other pods

  - seccomp profiles
      Block ptrace and /proc/mem access from within containers
      Prevents container-side memory introspection

For 99% of companies:
─────────────────────
  tmpfs >> etcd in terms of security
  Threat of node RAM dump << threat of misconfigured kubectl RBAC
```

---

## 6. ESO vs CSI Driver — Full Comparison

### 6.1 Feature Comparison Table

```
┌────────────────────────────┬─────────────────┬─────────────────┬──────────────────────┐
│  Criteria                  │  Native Secret  │  ESO            │  CSI Driver + ASCP   │
├────────────────────────────┼─────────────────┼─────────────────┼──────────────────────┤
│  Secret values in Git?     │  YES ❌         │  NO  ✅         │  NO  ✅              │
│  Secret stored in etcd?    │  YES ❌         │  YES ❌         │  NO  ✅              │
│  kubectl shows values?     │  YES ❌         │  YES ❌         │  NO  ✅              │
│  Centralized management?   │  NO  ❌         │  YES ✅         │  YES ✅              │
│  Works with env vars?      │  YES ✅         │  YES ✅         │  Only w/ secretObjects│
│  App needs AWS creds?      │  NO  ✅         │  NO  ✅         │  YES (each app SA)   │
│  GitOps / ArgoCD friendly? │  NO  ❌         │  YES ✅         │  YES ✅              │
│  Auto-rotation?            │  NO  ❌         │  YES (interval) │  YES (pod restart)   │
│  Compliance: no etcd?      │  FAIL ❌        │  FAIL ❌        │  PASS ✅             │
│  Works on non-EKS?         │  YES ✅         │  YES ✅         │  YES (diff provider) │
│  Operational complexity    │  Low            │  Medium         │  Higher              │
│  Best for                  │  Dev only       │  Most prod teams│  Compliance-heavy    │
└────────────────────────────┴─────────────────┴─────────────────┴──────────────────────┘
```

---

### 6.2 Where Does the Secret Value Live?

This table shows exactly where each copy of the secret value sits at each stage of each approach:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WHERE DOES THE SECRET VALUE LIVE?                        │
├────────────────────────────┬────────────────────────────────────────────────┤
│  ESO approach              │  CSI Driver + ASCP approach                    │
├────────────────────────────┼────────────────────────────────────────────────┤
│                            │                                                │
│  AWS Secrets Manager       │  AWS Secrets Manager                           │
│    └─ source of truth      │    └─ source of truth                          │
│                            │                                                │
│  etcd (control plane disk) │  etcd                                          │
│    └─ K8s Secret object    │    └─ NOTHING. Secret never goes here.         │
│       stored here          │                                                │
│       base64 encoded       │                                                │
│       NOT encrypted by def │                                                │
│                            │                                                │
│  Node RAM (tmpfs)          │  Node RAM (tmpfs)                              │
│    └─ if using volume      │    └─ ALWAYS. Only place secret lives          │
│       mount for the secret │       on the node. RAM from EC2 instance.      │
│                            │                                                │
│  Node disk                 │  Node disk                                     │
│    └─ NEVER                │    └─ NEVER                                    │
│                            │                                                │
│  EFS / EBS                 │  EFS / EBS                                     │
│    └─ NEVER                │    └─ NEVER                                    │
│                            │                                                │
├────────────────────────────┼────────────────────────────────────────────────┤
│  Risk: if etcd is breached │  Risk: none in cluster storage.                │
│  and not encrypted,        │  Secret only exists in RAM during pod          │
│  secrets are exposed.      │  lifetime. Harder to exfiltrate.               │
└────────────────────────────┴────────────────────────────────────────────────┘
```

---

### 6.3 Production Decision Framework

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  REAL PRODUCTION DECISION FRAMEWORK                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Use ESO when:                                                              │
│                                                                             │
│    ✓ Your app reads secrets as ENV VARS                                     │
│      (most common — 12-factor apps, Node/Python/Go services)                │
│                                                                             │
│    ✓ You are on multiple clouds or multiple secret backends                 │
│      (ESO supports AWS, GCP, Azure, Vault, 1Password in one operator)       │
│                                                                             │
│    ✓ You want simplicity — one operator, less moving parts                  │
│                                                                             │
│    ✓ Secret rotation does not need to be instant                            │
│      (ESO re-syncs on interval, pods may need restart for env vars)         │
│                                                                             │
│    ✓ Your threat model accepts secrets in etcd                              │
│      (with etcd encryption at rest enabled — acceptable for most)           │
│                                                                             │
│    ✓ Most startups, product teams, SaaS companies                           │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Use CSI Driver + ASCP when:                                                │
│                                                                             │
│    ✓ Compliance requires secrets never touch etcd                           │
│      (PCI-DSS, HIPAA, SOC2 Type II, FedRAMP)                               │
│                                                                             │
│    ✓ You need kubectl get secret to show NOTHING                            │
│      (ops team must not be able to read secrets via kubectl)                │
│                                                                             │
│    ✓ You need live secret rotation without pod restart                      │
│      (CSI driver can update the mounted file in a running pod)              │
│                                                                             │
│    ✓ Your app reads config as FILES not env vars                            │
│      (Java apps, apps with config file patterns like /etc/app/config.json)  │
│                                                                             │
│    ✓ Fintech, healthcare, government, enterprise                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

The single deciding question:
────────────────────────────────────────────────────────────────────────────
  "Does your compliance or security requirement say
   kubectl get secret must return nothing?"

    YES → CSI Driver + ASCP
    NO  → ESO (simpler, more flexible)
```

---

### 6.4 Real Example: Redis and ElastiCache

A concrete production scenario that illustrates exactly when and why CSI Driver is the right choice:

```
Scenario: Application connects to AWS ElastiCache Redis
─────────────────────────────────────────────────────────
  Secret: REDIS_AUTH_TOKEN = "xK9#mP2$nQ7..."


With ESO:
──────────
  kubectl get secret redis-secret -n my-app
  → shows: REDIS_AUTH_TOKEN: eEs5I21QMiRuUTck...  (base64)
  → any developer with kubectl access can decode it in 5 seconds:
      echo "eEs5I21QMiRuUTck..." | base64 -d
  → lives in etcd indefinitely
  → present in every etcd backup


With CSI Driver + ASCP:
────────────────────────
  kubectl get secret -n my-app
  → No resources found.
  → secret never created as a K8s object
  → lives only in pod RAM at /mnt/secrets/redis-token
  → ops team cannot accidentally expose it via kubectl
  → audit log in CloudTrail shows only pod startup as the access event
  → when pod dies, secret is gone from the cluster entirely


Why this matters for ElastiCache specifically:
───────────────────────────────────────────────
  ElastiCache AUTH token grants full read/write access to Redis
  Redis often holds session data, cache data, sometimes queues
  Compromise of the token = full Redis access
  CSI approach means the token is never visible to anyone
  via standard Kubernetes tooling — even cluster admins
```

---

### 6.5 Decision Tree

```
Do you need secrets out of Git?
    │
    ├── NO  → Native K8s Secret (only for local dev)
    │
    └── YES
          │
          ▼
    Do you have compliance requirements that mandate
    secrets never exist in etcd?
    (PCI-DSS, HIPAA, SOC2 strict, FedRAMP)
          │
          ├── NO  → Use ESO
          │         Simple, GitOps-friendly, widely adopted
          │         Works great for most product teams
          │         env vars work natively
          │
          └── YES → Use CSI Driver + ASCP
                    Secrets bypass etcd entirely
                    More operational complexity
                    Each app SA needs its own IAM role
                    kubectl get secret returns nothing
```

**One-Line Summary:**

```
ESO        → solves secret MANAGEMENT  (centralized, auto-synced)
CSI Driver → solves secret EXPOSURE    (never touches etcd)
```

---

## 7. Production Architecture — ArgoCD + ESO + AWS

```
┌────────────────────────────────────────────────────────────────────────┐
│  Git Repository  (zero secret values ever committed here)              │
│────────────────────────────────────────────────────────────────────────│
│  apps/my-service/                                                      │
│  ├── namespace.yaml            ← namespace + label for SecretStore     │
│  ├── deployment.yaml           ← references K8s Secret by name only    │
│  ├── external-secret.yaml      ← ExternalSecret pointer (no values)    │
│  └── cluster-secret-store.yaml ← connection config to AWS             │
└──────────────────────────────┬─────────────────────────────────────────┘
                               │ ArgoCD watches this repo
                               ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     Two Parallel Pipelines                             │
│                                                                        │
│  ┌──────────────────────────────┐   ┌──────────────────────────────┐  │
│  │  PIPELINE 1: ArgoCD          │   │  PIPELINE 2: ESO             │  │
│  │  (app lifecycle)             │   │  (secret lifecycle)          │  │
│  │──────────────────────────────│   │──────────────────────────────│  │
│  │  Detects Git change          │   │  Watches ExternalSecret CRDs │  │
│  │  Applies to cluster:         │   │  On refreshInterval:         │  │
│  │  - Namespace                 │   │  Calls AWS SM API            │  │
│  │  - Deployment                │   │  Creates/updates K8s Secret  │  │
│  │  - ExternalSecret (CRD)      │   │                              │  │
│  │  - ClusterSecretStore        │   │                              │  │
│  └──────────────┬───────────────┘   └──────────────┬───────────────┘  │
│                 │                                  │                  │
└─────────────────┼──────────────────────────────────┼──────────────────┘
                  │ both converge in cluster          │
                  ▼                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│  namespace: my-service                                                 │
│  ┌──────────────────────┐      ┌──────────────────────────────────┐   │
│  │  ExternalSecret      │─────►│  kind: Secret (auto-created)     │   │
│  │  (ArgoCD applied)    │      │  (ESO created, not you)          │   │
│  └──────────────────────┘      └────────────────┬─────────────────┘   │
│                                                 ▼                     │
│                                 ┌──────────────────────────────────┐  │
│                                 │  Deployment / Pod                │  │
│                                 │  env: DB_PASSWORD                │  │
│                                 │  (reads K8s Secret normally)     │  │
│                                 └──────────────────────────────────┘  │
└─────────────────────────────────────┬──────────────────────────────────┘
                                      │ ESO fetches from
┌─────────────────────────────────────▼──────────────────────────────────┐
│  AWS Account                                                           │
│  ┌─────────────────────────────┐   ┌────────────────────────────────┐ │
│  │  AWS Secrets Manager        │   │  EKS Pod Identity / IRSA       │ │
│  │  /prod/myapp/db-password    │   │  ESO SA → eso-reader role      │ │
│  │  /prod/myapp/api-key        │   │  Permission: SM:GetSecretValue  │ │
│  └─────────────────────────────┘   └────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

**Secret Rotation Flow:**

```
DevOps rotates secret in AWS Secrets Manager
    │
    │  aws secretsmanager put-secret-value \
    │    --secret-id prod/myapp/db-password \
    │    --secret-string '{"password":"newvalue"}'
    ▼
AWS Secrets Manager updated

ESO polls on refreshInterval (e.g. every 1h)
    │
    ▼
ESO detects new value → updates K8s Secret
    │
    ├── Secret mounted as VOLUME:
    │     Pod picks up new value automatically ✅
    │     No pod restart needed
    │
    └── Secret used as ENV VAR:
          Pod must restart to pick up new value ⚠️
          (env vars set at container start time)
```

**Final Mental Model — What Lives Where:**

```
┌──────────────────────┬──────────────────────────┬──────────────────────────┐
│  COMPONENT           │  WHERE IT LIVES           │  PURPOSE                 │
├──────────────────────┼──────────────────────────┼──────────────────────────┤
│  Secret VALUES       │  AWS Secrets Manager      │  Single source of truth  │
│  ExternalSecret      │  Git + etcd (CRD)         │  Pointer to AWS path     │
│  ClusterSecretStore  │  Git + etcd (CRD)         │  Connection config       │
│  kind: Secret        │  etcd only                │  Auto-created by ESO     │
│  IAM Role            │  AWS IAM                  │  Permission to read SM   │
│  Pod Identity        │  AWS EKS                  │  Auth: pod → IAM Role    │
│  ArgoCD              │  Cluster                  │  Applies Git → Cluster   │
│  ESO Controller      │  Cluster                  │  Syncs AWS → K8s Secret  │
│  tmpfs (CSI)         │  Node RAM (EC2 instance)  │  In-memory secret mount  │
│  EFS / EBS           │  AWS storage              │  Persistent app data only│
├──────────────────────┼──────────────────────────┼──────────────────────────┤
│  NEVER IN GIT        │  Secret values            │  ← the whole point       │
└──────────────────────┴──────────────────────────┴──────────────────────────┘

One-line role of each object:
─────────────────────────────────────────────────────────────────────────────
IAM Role           → "ESO / ASCP is ALLOWED to read these secrets"
Pod Identity/IRSA  → "This pod IS the ESO service account"
ClusterSecretStore → "Connect to THIS AWS account/region/service"
ExternalSecret     → "Fetch THIS secret and name it THAT"
kind: Secret       → The result ESO creates — app consumes this
SecretProviderClass→ CSI equivalent of ExternalSecret — no etcd write
tmpfs              → RAM-backed mount on EC2 worker node, not EFS, not EBS
ConfigMap          → Non-sensitive config only, never for secrets
StorageClass       → Disk provisioning, completely unrelated to secrets
EFS                → Persistent shared file storage, completely unrelated
```

---

*Kubernetes Secrets Management — ESO + CSI Driver + ASCP + ArgoCD + Storage Architecture*
