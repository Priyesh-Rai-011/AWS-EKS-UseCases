# 10_01 — EKS RBAC & IAM

## Problem

EKS cluster is up. Anyone with AWS credentials can hit the API endpoint. How do you control
who can access the cluster and what they can do once inside?

Answer: two separate layers.

```text
Layer 1 — AWS IAM (authentication):    WHO are you?
Layer 2 — Kubernetes RBAC (authorization): WHAT can you do?
```

---

## Implementation map

```text
10_01_EKS_RBAC_IAM/
├── terraform/
│   ├── iam.tf              ← 8 IAM roles, 8 users, groups, trust policies
│   └── access_entries.tf   ← IAM role ARN → k8s username + k8s groups (the bridge)
│
├── 00_concepts/            ← Read ALL of these before touching anything
│   ├── 01_authentication_vs_authorization.md
│   ├── 02_iam_vs_rbac.md
│   ├── 03_cluster_creator.md
│   ├── 04_aws_auth_vs_access_entries.md
│   ├── 05_end_to_end_flow.md
│   ├── 06_kubectl_to_api_server.md     ← token flow, API pipeline, etcd vs cache
│   ├── 07_clusterrole_vs_role.md       ← scope decision + blast radius principle
│   └── 08_kubernetes_groups_and_audit.md ← groups, audit trail, CloudTrail cross-ref
│
├── 01_iam_setup/           ← explains terraform/iam.tf
├── 02_access_entries/      ← explains terraform/access_entries.tf
│
├── 03_rbac_manifests/
│   └── k8s-manifests/
│       ├── 00-namespaces.yaml
│       ├── cluster-roles/   ← devops-admin, devops-viewer, readonly, security-audit
│       ├── roles/           ← backend-admin, backend-dev, frontend-dev
│       ├── cluster-role-bindings/
│       └── role-bindings/
│
└── 04_validation/
    └── scripts/             ← test-alice.sh ... test-grace.sh
```

---

## Personas

```text
Alice   (Lead DevOps)     → eks-devops-admin-role    → cluster-wide, exec yes
Bob     (DevOps Engineer) → eks-devops-role           → cluster-wide, read+rollout
Charlie (Backend Lead)    → eks-backend-dev-admin-role→ backend-prod only, exec yes
Dave    (Backend Dev)     → eks-backend-dev-role      → backend-prod only, rollout
Eve     (Frontend Dev)    → eks-frontend-dev-role     → frontend-prod only, read+logs
Frank   (On-call SRE)     → eks-devops-role           → same as Bob
Grace   (Security)        → eks-security-role         → cluster-wide, secrets list
Henry   (Break-glass)     → eks-cluster-admin-role    → system:masters, vault-locked
```

---

## Execution order

```bash
Step 1: cd 00_concepts/ — read all 8 docs
Step 2: cd terraform/ && terraform apply — creates IAM + access entries
Step 3: kubectl apply -f 03_rbac_manifests/k8s-manifests/ — loads RBAC into cluster
Step 4: bash 04_validation/scripts/test-dave.sh — prove it works
```

---

## Revision notes

- IAM = authentication only. RBAC = authorization only. Never confuse them.
- Access Entry = the bridge. Group names MUST match between access_entries.tf and YAML bindings.
- ClusterRole for ops/security (they work everywhere). Role for devs (namespace isolation).
- Secrets protection = simply don't list `secrets` in the Role rules. No extra mechanism.
- `system:masters` needs no RBAC manifest — built-in K8s privilege group. Break-glass only.
- RBAC is additive — no explicit deny. Omission = denied.
