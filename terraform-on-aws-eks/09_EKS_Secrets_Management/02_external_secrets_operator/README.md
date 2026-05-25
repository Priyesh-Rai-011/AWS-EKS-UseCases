# 02 — External Secrets Operator

etcd is the problem. Every secret your cluster holds lives in a key-value store on the control plane. base64 encoded. Accessible to anyone with the right kubeconfig. No audit trail. No rotation. No central management.

The question isn't "how do we secure etcd." The question is: what if secrets never lived there in the first place?

ESO's answer: AWS Secrets Manager is the source of truth. The operator syncs secrets into Kubernetes automatically. Your app still reads env vars — it has no idea AWS is involved.

---

## Questions

- [Secret lives in AWS Secrets Manager. How does the pod prove it's allowed to read it?](#q1-secret-lives-in-aws-secrets-manager-how-does-the-pod-prove-its-allowed-to-read-it)
- [What is IRSA actually doing?](#q2-what-is-irsa-actually-doing)
- [What is ESO? What is it actually doing?](#q3-what-is-eso-what-is-it-actually-doing)
- [Three new CRDs — what does each one do?](#q4-three-new-crds--what-does-each-one-do)
- [Full ESO flow — AWS SM to pod env var](#q5-full-eso-flow--aws-sm-to-pod-env-var)
- [Wait — ESO still writes a K8s Secret to etcd. Are we back to square one?](#q6-wait--eso-still-writes-a-k8s-secret-to-etcd-are-we-back-to-square-one)
- [Why 3 separate SM secrets instead of 1?](#q7-why-3-separate-sm-secrets-instead-of-1)
- [Why does Terraform create only the secret shell, with no value?](#q8-why-does-terraform-create-only-the-secret-shell-with-no-value)
- [What happens during terraform destroy?](#q9-what-happens-during-terraform-destroy)

---

## Folder structure

```text
02_external_secrets_operator/
├── terraform/
│   ├── main.tf                       ← wires all 6 modules
│   ├── variables.tf
│   ├── locals.tf
│   ├── backend.tf                    ← remote state: s3://learning-remotebackend2
│   ├── provider.tf
│   └── modules/
│       ├── 01_vpc/                   ← VPC, subnets, NAT GW
│       ├── 02_eks/                   ← EKS cluster, OIDC provider, node group
│       ├── 03_bastion/               ← EC2 bastion, SSM only
│       ├── 04_ecr/                   ← ECR repo for pulseauth image
│       ├── 05_eso_iam/               ← IAM role for ESO (IRSA, pinned to external-secrets SA)
│       └── 06_secrets_manager/       ← Creates 3 SM secret shells (no values)
│
├── k8s-manifests/
│   ├── 00-namespace.yaml             ← ns: pulseauth
│   ├── 01-storageclass.yaml          ← ebs-gp3-sc (postgres PVC)
│   ├── 03-secretstore.yaml           ← HOW ESO connects to SM + which IAM role
│   ├── 04-externalsecret-db.yaml     ← WHAT to fetch: postgres credentials
│   ├── 05-externalsecret-redis.yaml  ← WHAT to fetch: redis credentials
│   ├── 06-externalsecret-mail.yaml   ← WHAT to fetch: mail credentials
│   ├── 07-postgres-statefulset.yaml
│   ├── 08-postgres-service.yaml      ← ClusterIP headless
│   ├── 09-redis-deployment.yaml
│   ├── 10-redis-service.yaml
│   ├── 11-pulseauth-deployment.yaml
│   ├── 12-pulseauth-service.yaml     ← LoadBalancer (NLB)
│   └── INSTALL-ORDER.md
│
├── deployment-steps.md               ← exact commands, expected output
└── troubleshooting.md                ← failures, debug commands, known gotchas
```

---

## Q1. Secret lives in AWS Secrets Manager. How does the pod prove it's allowed to read it?

It doesn't. The pod never talks to AWS. ESO does.

ESO is a controller running in `external-secrets` namespace. It gets an IAM identity via IRSA — a JWT token Kubernetes mounts into the pod, which ESO exchanges with STS for temporary AWS credentials. ESO then calls `secretsmanager:GetSecretValue`, fetches the secret, and creates a standard K8s Secret object. The app pod reads that K8s Secret as env vars. Zero AWS code in the app.

```text
ESO pod starts
    │
    │  K8s mounts OIDC JWT at:
    │  /var/run/secrets/eks.amazonaws.com/serviceaccount/token
    ▼
STS: AssumeRoleWithWebIdentity
    │  OIDC provider validates JWT signature
    │  checks: sub == system:serviceaccount:external-secrets:external-secrets
    │  checks: aud == sts.amazonaws.com
    ▼
Temporary credentials (scoped to external-secrets-operator-role)
    ▼
ESO calls secretsmanager:GetSecretValue
    ▼
Creates K8s Secret → app pod reads env vars
```

→ IRSA trust policy: [`terraform/modules/05_eso_iam/main.tf`](./terraform/modules/05_eso_iam/main.tf)

---

## Q2. What is IRSA actually doing?

IRSA = IAM Roles for Service Accounts. It is the mechanism that links a Kubernetes ServiceAccount to an AWS IAM Role without any static credentials.

Three things must exist for IRSA to work:

```text
1. OIDC Provider resource in AWS IAM
   → tells AWS "trust JWTs issued by this EKS cluster"
   → terraform/modules/02_eks/main.tf

2. IAM Role trust policy with StringEquals condition
   → only this SA in this namespace can assume this role
   → terraform/modules/05_eso_iam/main.tf

3. ServiceAccount annotation in K8s
   → eks.amazonaws.com/role-arn: <arn>
   → set by Helm during ESO install (--set serviceAccount.annotations...)
```

Miss any one of these and IRSA silently fails. The pod starts. The ESO controller starts. And then every ExternalSecret shows `InvalidProviderConfig` with no obvious cause.

---

## Q3. What is ESO? What is it actually doing?

ESO is a Kubernetes Operator — it follows the operator pattern: watch CRDs, reconcile state, repeat.

```text
ESO controller loop (runs every refreshInterval):

  Watch ExternalSecret objects
          │
          ▼
  For each ExternalSecret:
    - read SecretStore (how to connect to SM)
    - fetch secret value from SM using IRSA creds
    - create or update K8s Secret with fetched values
          │
          ▼
  Sleep until next refreshInterval (default: 1h)
```

It introduces three new CRDs into your cluster. Understanding what each one does is the entire mental model of ESO.

---

## Q4. Three new CRDs — what does each one do?

**SecretStore** — answers HOW: how do I connect to AWS SM, and which IAM role do I use?

```yaml
# k8s-manifests/03-secretstore.yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: pulseauth
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets          # ESO's SA (cross-namespace)
            namespace: external-secrets
```

One SecretStore per namespace. References the ESO ServiceAccount that has IRSA credentials.

**ExternalSecret** — answers WHAT: which secret in SM, which keys to extract, what K8s Secret to create?

```yaml
# k8s-manifests/04-externalsecret-db.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: pulseauth-db-external-secret
  namespace: pulseauth
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager        # points to the SecretStore above
    kind: SecretStore
  target:
    name: pulseauth-db-secret        # K8s Secret ESO will create
    creationPolicy: Owner
  data:
    - secretKey: DB_PASSWORD         # key in the K8s Secret
      remoteRef:
        key: eks-secrets-dev/pulseauth/postgres   # SM secret name
        property: DB_PASSWORD                     # field inside the JSON blob
```

**K8s Secret** (created by ESO automatically) — standard Secret object, consumed by pods as env vars. You never write this manifest. ESO owns it.

→ [`k8s-manifests/03-secretstore.yaml`](./k8s-manifests/03-secretstore.yaml)
→ [`k8s-manifests/04-externalsecret-db.yaml`](./k8s-manifests/04-externalsecret-db.yaml)

---

## Q5. Full ESO flow — AWS SM to pod env var

```text
  ┌─────────────────────────────┐     ┌──────────────────────────────────────────┐
  │  AWS Secrets Manager        │     │  Kubernetes (EKS)                        │
  │                             │     │                                          │
  │  eks-secrets-dev/           │     │  ┌──────────────────────────────────┐   │
  │    pulseauth/postgres  ──────┼─────┼─▶│  ESO Controller                  │   │
  │    pulseauth/redis     ──────┼─────┼─▶│  (external-secrets namespace)    │   │
  │    pulseauth/mail      ──────┼─────┼─▶│                                  │   │
  │                             │     │  │  IRSA JWT → STS → temp creds     │   │
  │  (IRSA-authenticated        │     │  │  SecretStore: aws-secrets-manager │   │
  │   CloudTrail-audited)       │     │  │  ExternalSecret × 3              │   │
  └─────────────────────────────┘     │  └────────────────┬─────────────────┘   │
                                      │                   │ creates/syncs        │
                                      │                   ▼                      │
                                      │  ┌──────────────────────────────────┐   │
                                      │  │  etcd                            │   │
                                      │  │  pulseauth-db-secret             │   │
                                      │  │  pulseauth-redis-secret          │   │
                                      │  │  pulseauth-mail-secret           │   │
                                      │  └────────────────┬─────────────────┘   │
                                      │                   │ envFrom              │
                                      │        ┌──────────┼──────────┐          │
                                      │        ▼          ▼          ▼          │
                                      │  ┌──────────┐ ┌───────┐ ┌──────────┐  │
                                      │  │ postgres │ │ redis │ │pulseauth │  │
                                      │  │  (DB_*)  │ │(RED.*)│ │ (all 3)  │  │
                                      │  └──────────┘ └───────┘ └──────────┘  │
                                      └──────────────────────────────────────────┘
```

---

## Q6. Wait — ESO still writes a K8s Secret to etcd. Are we back to square one?

Partially. This is the most important nuance of ESO.

What ESO improves:

- Source of truth is AWS SM, not etcd — rotate in SM, all clusters pick it up
- Access is IAM-controlled and CloudTrail-audited
- No credentials in Git, no credentials in `.tfstate`

What ESO does NOT fix:

- The synced K8s Secret still lands in etcd
- Anyone with `kubectl get secret` access can read the value
- etcd backup = credential backup

ESO makes the operational problem much better. It does not make the etcd exposure go away. If your threat model requires "secrets must never touch etcd," ESO is not sufficient. That's the CSI approach.

---

## Q7. Why 3 separate SM secrets instead of 1?

Blast radius and least privilege.

```text
One big secret approach:
  eks-secrets-dev/pulseauth/all  →  DB_*, REDIS_*, MAIL_* all in one blob
  IAM policy: GetSecretValue on one ARN
  Risk: if ESO role is compromised, attacker gets everything in one call

Three separate secrets:
  eks-secrets-dev/pulseauth/postgres  →  postgres only
  eks-secrets-dev/pulseauth/redis     →  redis only
  eks-secrets-dev/pulseauth/mail      →  mail only
  IAM policy: GetSecretValue on 3 exact ARNs
  Risk: one secret leaked does not expose the others
```

The IAM policy in this stack grants access to exact ARNs, not wildcards:

```hcl
# terraform/modules/05_eso_iam/main.tf
Resource = var.secret_arns   # exact ARNs from module.secrets_manager outputs
```

→ [`terraform/modules/05_eso_iam/main.tf`](./terraform/modules/05_eso_iam/main.tf)
→ [`terraform/modules/06_secrets_manager/main.tf`](./terraform/modules/06_secrets_manager/main.tf)

---

## Q8. Why does Terraform create only the secret shell, with no value?

`.tfstate` is plaintext JSON stored in S3. If Terraform manages the actual secret value, that value is in the state file. Anyone with S3 read access to the backend bucket has your production password — forever, in every state snapshot ever taken.

```text
BAD (never do this):
  resource "aws_secretsmanager_secret_version" "postgres" {
    secret_string = jsonencode({ DB_PASSWORD = "mypassword" })
  }
  → "mypassword" is now in terraform.tfstate in S3

CORRECT (two-phase pattern):
  Phase 1 — Terraform creates the shell:
    resource "aws_secretsmanager_secret" "postgres" {
      name = "eks-secrets-dev/pulseauth/postgres"
    }
    # no aws_secretsmanager_secret_version resource — no value in state

  Phase 2 — CLI seeds the real value (run once, not in TF):
    aws secretsmanager put-secret-value \
      --secret-id eks-secrets-dev/pulseauth/postgres \
      --secret-string '{"DB_PASSWORD":"...","DB_USER":"..."}'
```

Terraform output gives you the ARN. The IAM policy uses that exact ARN. The value is seeded separately and never touches Terraform state.

→ [`terraform/modules/06_secrets_manager/main.tf`](./terraform/modules/06_secrets_manager/main.tf)

---

## Q9. What happens during terraform destroy?

`prevent_destroy = true` is set on all three SM secrets. This is intentional.

```text
terraform destroy
    │
    ▼
Terraform tries to delete eks-secrets-dev/pulseauth/postgres
    │
    ▼
ERROR: Instance cannot be destroyed
  │  on modules/06_secrets_manager/main.tf:
  │  lifecycle { prevent_destroy = true }
    ▼
destroy halts. Infrastructure partially destroyed.
```

This is the production pattern. Terraform halting is the correct behavior — it prevents an accidental `destroy` from wiping production credentials.

**Cleanup sequence:**

```bash
# Step 1: manually delete secrets via AWS CLI
aws secretsmanager delete-secret \
  --secret-id eks-secrets-dev/pulseauth/postgres \
  --force-delete-without-recovery --region ap-south-1

aws secretsmanager delete-secret \
  --secret-id eks-secrets-dev/pulseauth/redis \
  --force-delete-without-recovery --region ap-south-1

aws secretsmanager delete-secret \
  --secret-id eks-secrets-dev/pulseauth/mail \
  --force-delete-without-recovery --region ap-south-1

# Step 2: remove from Terraform state (resource is gone, TF doesn't need to track it)
terraform state rm module.secrets_manager.aws_secretsmanager_secret.postgres
terraform state rm module.secrets_manager.aws_secretsmanager_secret.redis
terraform state rm module.secrets_manager.aws_secretsmanager_secret.mail

# Step 3: destroy succeeds now
terraform destroy
```

---

## Why IRSA, not Pod Identity, for ESO?

ESO is cluster-wide. One controller manages secrets for every namespace, every app.

Pod Identity gives ESO one role — blast radius is everything. If the ESO IAM role is ever compromised, an attacker calls `GetSecretValue` on every secret in every namespace in one shot.

IRSA pins the trust to a specific ServiceAccount in a specific namespace:

```hcl
# terraform/modules/05_eso_iam/main.tf
Condition = {
  StringEquals = {
    "${oidc_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
    "${oidc_url}:aud" = "sts.amazonaws.com"
  }
}
```

Only the ESO controller SA in `external-secrets` namespace can assume this role. A compromised app pod in `pulseauth` namespace gets nothing, even if it tries.

```text
Pod Identity (wrong for ESO)        IRSA (correct for ESO)
────────────────────────────────    ────────────────────────────────
One role, cluster-wide              Pinned to one SA + one namespace
ESO compromise = all secrets        ESO compromise = only its own creds
No OIDC provider required           Requires OIDC provider resource
Fine for single app, one role       Required for scoped delegation
```

---

## IAM roles in this stack

| Role | Assumed by | Permissions |
| ---- | ---------- | ----------- |
| `eks-dev-cluster-role` | `eks.amazonaws.com` | EKS control plane operations |
| `eks-dev-node-role` | `ec2.amazonaws.com` | Join cluster, pull ECR, SSM |
| `external-secrets-operator-role` | ESO SA via IRSA | `GetSecretValue` on 3 exact SM ARNs, `GetParameter` on `/eks-secrets-dev/pulseauth/*` |

---

## Verdict

ESO solves the source-of-truth problem. Secrets live in AWS SM, accessed via IAM, auditable via CloudTrail, rotatable without touching app code.

What it doesn't solve: synced secrets still land in etcd. The value is protected at the AWS layer but still present inside the cluster.

If your compliance requirement is "secrets must never be stored in etcd," ESO is not the answer.

→ [`03_csi_driver_ascp/`](../03_csi_driver_ascp/)
