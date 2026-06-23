# EKS RBAC + IAM — FinTech Team Access Control

Eight engineers. Eight different jobs. Zero overlap in what they can touch.

RBAC default-deny makes this work: if a resource isn't listed in your Role, you can't see it.
No explicit deny required. The permission matrix exists entirely in the gaps.

---

## Full flow

```text
IAM User ──► IAM Group ──► sts:AssumeRole ──► IAM Role
                                                   │
                              EKS Access Entry ◄───┘
                                   │ maps role ARN → k8s username + k8s groups
                          ClusterRoleBinding / RoleBinding
                                   │ subject: Group name must match exactly
                          ClusterRole / Role ──► ALLOW (only; omission = DENY)
```

---

## Core concept: scope is in the binding, not the role

Wrong instinct: "just give everyone a ClusterRole with restricted verbs."

The scope of the **binding** determines what namespace a permission covers, not the role's
content. The same ClusterRole can be cluster-wide or namespace-scoped depending on how
it's bound.

```text
CLUSTER-WIDE                          NAMESPACE-SCOPED
──────────────────────────            ──────────────────────────
ClusterRole                           ClusterRole  OR  Role
     +                                      +
ClusterRoleBinding                    RoleBinding (namespace: backend-prod)
     =                                      =
every namespace                       backend-prod ONLY
```

Alice (devops-admin): ClusterRole + ClusterRoleBinding → manages pods anywhere.
Charlie (backend-admin): Role + RoleBinding in backend-prod → `kubectl get pods -n frontend-prod` → DENIED.

This is how you grant Charlie backend ownership without letting him touch frontend.
Secrets protection: don't list `secrets` in the Role rules. No extra mechanism. Omission = denial.

---

## Terraform modules

```text
modules/vpc             → 3-AZ VPC, public/private subnets, NAT GW
modules/eks             → cluster, node group, OIDC provider, addons, bastion access entry
modules/bastion         → EC2 SSM-only (no SSH, no key pairs)
modules/ecr             → ECR repo (pulseauth:latest)
modules/secrets_manager → blank secret shells (seeded via CLI after apply, never in .tfstate)
modules/eso_iam         → IRSA role: pulseauth-sa → Secrets Manager get
modules/rbac_personas   → 8 IAM users, 8 roles, 6 IAM groups, EKS access entries
modules/frontend_s3     → S3 static website bucket for Angular build
```

`rbac_personas` uses a locals map — adding a new engineer is one map entry, zero new resource
blocks. IAM group membership auto-grants the correct `sts:AssumeRole` policy.

---

## Kubernetes workloads

```text
backend-prod namespace
├── pulseauth-sa (ServiceAccount)
│     └── IRSA → eks-rbac-dev-pulseauth-eso-role → Secrets Manager
│
├── pulseauth-secret-store (SecretStore, auth via pulseauth-sa JWT)
├── pulseauth-postgres-external-secret → pulseauth-postgres-secret
│     └── SM key: eks-rbac-dev/pulseauth/postgres
├── pulseauth-mail-external-secret → pulseauth-mail-secret
│     └── SM key: eks-rbac-dev/pulseauth/mail
│
├── postgres (StatefulSet)  :5432  EBS 5Gi  subPath:pgdata
├── postgres-svc             ClusterIP headless
│
├── redis (Deployment)       :6379  redis:7-alpine
├── redis-svc                ClusterIP
│
├── pulseauth (Deployment)   :8080  ECR pulseauth:latest
│     env: pulseauth-postgres-secret + pulseauth-mail-secret + redis-svc DNS
│
└── pulseauth-svc            LoadBalancer  :80 → pod :8080  (creates NLB)

S3 (outside EKS)
└── eks-rbac-dev-frontend  static website → Angular → NLB endpoint
```

---

## Personas + IAM roles

| Persona    | Role                    | k8s group              | Scope                     | Secrets       | Exec |
| ---------- | ----------------------- | ---------------------- | ------------------------- | ------------- | ---- |
| alice      | devops-admin-role       | eks-devops-admins      | cluster-wide              | NO            | YES  |
| bob, frank | devops-role             | eks-devops             | cluster-wide              | NO            | NO   |
| charlie    | backend-dev-admin-role  | eks-backend-admins     | backend-prod              | NO            | YES  |
| dave       | backend-dev-role        | eks-backend-devs       | backend-prod              | NO            | NO   |
| eve        | frontend-dev-role       | eks-frontend-devs      | backend-prod readonly     | NO            | NO   |
| grace      | security-role           | eks-security           | cluster-wide + RBAC audit | YES (list/get)| NO   |
| henry      | cluster-admin-role      | EKSClusterAdminPolicy  | full cluster              | YES           | YES  |

Grace is the only persona with `secrets: [get, list]` — audits what secrets exist, not values.
Henry has no IAM group. Direct user policy, EKS managed policy association, break-glass only.

---

→ Deploy: [deployment-steps.md](deployment-steps.md)
→ Debug:  [troubleshooting.md](troubleshooting.md)
