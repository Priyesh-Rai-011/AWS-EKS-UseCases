# 03 — CSI Driver + AWS Secrets & Configuration Provider (ASCP)

ESO solves the source-of-truth problem. Secrets live in AWS Secrets Manager. Rotation happens centrally. IAM controls access. All good.

But ESO still creates a Kubernetes Secret object. That object lives in etcd.

Now your compliance team runs a scan. They find credentials in etcd. PCI-DSS says no. HIPAA says no. SOC2 audit flags it. The question becomes: can we eliminate etcd from the secret lifecycle entirely?

That's what this folder solves.

---

## Questions

- [CSI for secrets? Isn't CSI the same driver used for EBS volumes?](#q1-csi-for-secrets-isnt-csi-the-same-driver-used-for-ebs-volumes)
- [CSI driver vs ASCP — two separate Helm installs. Why?](#q2-csi-driver-vs-ascp--two-separate-helm-installs-why)
- [What is SecretProviderClass? What does it define?](#q3-what-is-secretproviderclass-what-does-it-define)
- [Full CSI flow — AWS SM to pod](#q4-full-csi-flow--aws-sm-to-pod)
- [tmpfs — what is it and why does it matter?](#q5-tmpfs--what-is-it-and-why-does-it-matter)
- [Why 1 consolidated SM secret instead of 3?](#q6-why-1-consolidated-sm-secret-instead-of-3)
- [IRSA again — same pattern as ESO but different scope](#q7-irsa-again--same-pattern-as-eso-but-different-scope)
- [`secretObjects` — feature or security compromise?](#q8-secretobjects--feature-or-security-compromise)
- [The volume mount is not optional](#q9-the-volume-mount-is-not-optional)

---

## Folder structure

```text
03_csi_driver_ascp/
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
│       ├── 05_ascp_iam/              ← IAM role for ASCP (IRSA, pinned to pulseauth SA)
│       └── 06_secrets_manager/       ← Creates 1 consolidated SM secret shell (no value)
│
└── k8s-manifests/
    ├── 00-namespace.yaml             ← ns: pulseauth
    ├── 01-storageclass.yaml          ← ebs-gp3-sc (postgres PVC)
    ├── 02-serviceaccount.yaml        ← pulseauth SA with IRSA annotation
    ├── 03-secretproviderclass.yaml   ← core CSI config: which secret, which keys, how to mount
    ├── 04-postgres-statefulset.yaml  ← volumeMount triggers ASCP fetch
    ├── 05-postgres-service.yaml      ← ClusterIP headless
    ├── 06-redis-deployment.yaml
    ├── 07-redis-service.yaml
    ├── 08-pulseauth-deployment.yaml
    ├── 09-pulseauth-service.yaml     ← LoadBalancer (NLB)
    └── INSTALL-ORDER.md
```

---

## Q1. CSI for secrets? Isn't CSI the same driver used for EBS volumes?

CSI = Container Storage Interface. It is a standard API spec, not a specific driver.

In `07_EKS_EBS_CSI` you installed `aws-ebs-csi-driver` — an implementation of the CSI spec that provisions block volumes from EBS. Same interface, different backend.

Here, you install `secrets-store-csi-driver` — an implementation of the CSI spec that mounts secrets from external stores (SM, Vault, Azure Key Vault) as files into pods.

```text
CSI interface (standard K8s API)
    │
    ├── aws-ebs-csi-driver     →  provisions EBS block volumes  →  pod disk
    └── secrets-store-csi-driver  →  mounts secrets as files  →  pod tmpfs (RAM)
```

Same socket, completely different backend. The pod doesn't know which one it's talking to. It just sees a volume mount.

---

## Q2. CSI driver vs ASCP — two separate Helm installs. Why?

The CSI driver is generic. It knows how to mount files into pods via the standard interface. It has no idea what AWS Secrets Manager is.

ASCP (AWS Secrets & Configuration Provider) is the AWS-specific plugin. It knows how to authenticate to AWS, call `secretsmanager:GetSecretValue`, and hand the result to the CSI driver.

```text
K8s scheduler schedules pod
    │
    ▼
Kubelet: "pod needs a CSI volume"
    │
    ▼
secrets-store-csi-driver (generic socket)
    │  "which provider handles this?"
    ▼
ASCP plugin (AWS-specific)
    │  IRSA JWT → STS → temp creds → GetSecretValue
    ▼
Secret value returned to CSI driver
    │
    ▼
Mounted as tmpfs file inside container
```

Two installs:

```bash
# Install 1: the generic CSI driver
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true

# Install 2: the AWS-specific provider
helm install aws-secrets-provider aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  --namespace kube-system
```

---

## Q3. What is SecretProviderClass? What does it define?

SecretProviderClass is the new CRD you write instead of SecretStore + ExternalSecret. It is a single object that defines everything: which secret, which keys to extract, how to mount, and optionally what K8s Secret to create as a side effect.

```yaml
# k8s-manifests/03-secretproviderclass.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: pulseauth-secrets-provider
  namespace: pulseauth
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "eks-secrets-dev/pulseauth/all"   # one SM secret
        objectType: "secretsmanager"
        region: "ap-south-1"
        jmesPath:                                      # extract individual keys
          - path: DB_PASSWORD
            objectAlias: db-password
          - path: REDIS_PASSWORD
            objectAlias: redis-password
          # ... 14 keys total
  secretObjects:                                       # optional: create K8s Secret too
    - secretName: pulseauth-secrets
      type: Opaque
      data:
        - objectName: db-password
          key: DB_PASSWORD
        # ... all 14 keys
```

Three sections:

- `parameters.objects` — which SM secret, which provider, which region
- `jmesPath` — extract individual keys from the JSON blob in SM
- `secretObjects` — optional sync to a K8s Secret (goes to etcd — covered in Q8)

→ [`k8s-manifests/03-secretproviderclass.yaml`](./k8s-manifests/03-secretproviderclass.yaml)

---

## Q4. Full CSI flow — AWS SM to pod

```text
  ┌──────────────────────────┐     ┌────────────────────────────────────────────────────┐
  │  AWS Secrets Manager     │     │  Kubernetes (EKS)                                  │
  │                          │     │                                                    │
  │  eks-secrets-dev/        │     │  ┌──────────────────────────────────────────────┐ │
  │    pulseauth/all    ──────┼─────┼─▶│  ASCP (AWS provider plugin)                 │ │
  │    {                     │     │  │  IRSA JWT → STS → temp creds                │ │
  │      DB_HOST,            │     │  │  GetSecretValue on exact ARN                 │ │
  │      DB_PORT,            │     │  │  jmesPath extracts 14 keys                  │ │
  │      DB_NAME,            │     │  └──────────────────┬───────────────────────────┘ │
  │      DB_USER,            │     │                     │ hands to CSI driver          │
  │      DB_PASSWORD,        │     │                     ▼                              │
  │      REDIS_HOST,         │     │  ┌──────────────────────────────────────────────┐ │
  │      REDIS_PORT,         │     │  │  secrets-store-csi-driver (generic)          │ │
  │      REDIS_PASSWORD,     │     │  │  mounts files to pod tmpfs (RAM, no disk)    │ │
  │      MAIL_HOST,          │     │  └──────┬──────────────────┬─────────────────────┘ │
  │      MAIL_PORT,          │     │         │ /mnt/secrets/    │ secretObjects (opt.)  │
  │      MAIL_USER,          │     │         │ (tmpfs, RAM only) │ pulseauth-secrets     │
  │      MAIL_PASSWORD,      │     │         │                  ▼ (written to etcd)     │
  │      MAIL_SMTP_AUTH,     │     │    ┌────┴─────┐     ┌───────────────────────────┐ │
  │      MAIL_SMTP_TLS       │     │    │ postgres │     │  redis  │   pulseauth     │ │
  │    }                     │     │    │ (vol.mnt)│     │ (vol.mnt│   (vol.mnt +    │ │
  └──────────────────────────┘     │    └──────────┘     │  +envFr)│    envFrom)     │ │
                                   │                     └─────────┴─────────────────┘ │
                                   └────────────────────────────────────────────────────┘
```

---

## Q5. tmpfs — what is it and why does it matter?

tmpfs is an in-memory filesystem. Files written to tmpfs live in RAM only. No disk write ever happens.

| Property | Normal volume | tmpfs (CSI secrets mount) |
| -------- | ------------- | ------------------------- |
| Storage location | Node disk | RAM only |
| Survives pod death | Yes — file stays on disk | No — memory released |
| Disk snapshot exposure | Yes | No |
| etcd involved | Yes (K8s Secret) | No (unless `secretObjects`) |
| Forensic recovery possible | Yes | No |
| App reads secret via | File path or env var | File path (or env var via `secretObjects`) |

In the postgres StatefulSet manifest, the secrets-store volume is declared as CSI:

```yaml
# k8s-manifests/04-postgres-statefulset.yaml
volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: pulseauth-secrets-provider

volumeMounts:
  - name: secrets-store
    mountPath: /mnt/secrets
    readOnly: true
```

The mount point `/mnt/secrets` is tmpfs. No disk. No etcd (unless `secretObjects` is used).

→ [`k8s-manifests/04-postgres-statefulset.yaml`](./k8s-manifests/04-postgres-statefulset.yaml)

---

## Q6. Why 1 consolidated SM secret instead of 3?

In ESO, 3 separate secrets → 3 ExternalSecrets → 3 K8s Secrets → each pod gets exactly the secrets it needs.

In CSI, SecretProviderClass mounts one secret as a volume. To get multiple secrets, you'd need multiple volume mounts, multiple SecretProviderClasses, and significantly more YAML sprawl.

Instead: one SM secret, one JSON blob, all 14 keys together, one mount:

```text
ESO approach:
  eks-secrets-dev/pulseauth/postgres  →  ExternalSecret  →  pulseauth-db-secret
  eks-secrets-dev/pulseauth/redis     →  ExternalSecret  →  pulseauth-redis-secret
  eks-secrets-dev/pulseauth/mail      →  ExternalSecret  →  pulseauth-mail-secret
  3 AWS API calls. 3 K8s objects. 3 envFrom references.

CSI approach:
  eks-secrets-dev/pulseauth/all  →  SecretProviderClass  →  1 tmpfs mount  →  14 keys via jmesPath
  1 AWS API call. 1 K8s object. 1 volume mount per pod.
```

The tradeoff: the consolidated secret is larger blast radius in AWS SM (one ARN has all credentials). Offset by the fact that IAM access is still IRSA-scoped to the `pulseauth` SA only.

→ [`terraform/modules/06_secrets_manager/main.tf`](./terraform/modules/06_secrets_manager/main.tf)

---

## Q7. IRSA again — same pattern as ESO but different scope

In ESO, IRSA was given to the ESO controller SA (`external-secrets/external-secrets`). One role, cluster-wide controller.

In CSI, IRSA is given to the **application ServiceAccount** (`pulseauth/pulseauth`). Each app namespace gets its own role. Scoped to exactly one consolidated secret ARN.

```hcl
# terraform/modules/05_ascp_iam/main.tf
Condition = {
  StringEquals = {
    "${oidc_url}:sub" = "system:serviceaccount:pulseauth:pulseauth"
    "${oidc_url}:aud" = "sts.amazonaws.com"
  }
}
```

The `pulseauth` ServiceAccount is annotated with the ASCP role ARN:

```yaml
# k8s-manifests/02-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pulseauth
  namespace: pulseauth
  annotations:
    eks.amazonaws.com/role-arn: <ASCP_ROLE_ARN_PLACEHOLDER>
```

Every pod that needs secrets (`postgres`, `redis`, `pulseauth`) uses `serviceAccountName: pulseauth`. That SA carries the IRSA annotation. ASCP reads the JWT, exchanges with STS, gets temp creds, fetches the secret.

→ [`terraform/modules/05_ascp_iam/main.tf`](./terraform/modules/05_ascp_iam/main.tf)
→ [`k8s-manifests/02-serviceaccount.yaml`](./k8s-manifests/02-serviceaccount.yaml)

---

## Q8. `secretObjects` — feature or security compromise?

`secretObjects` in SecretProviderClass is optional. When present, ASCP creates a K8s Secret object as a side effect of the volume mount.

This is how PulseAuth uses it in this folder. Every pod does `envFrom: secretRef: pulseauth-secrets` to get env vars. But `pulseauth-secrets` only exists because of `secretObjects`.

| Property | WITHOUT `secretObjects` | WITH `secretObjects` (this folder) |
| -------- | ----------------------- | ----------------------------------- |
| Secret location | tmpfs only (`/mnt/secrets/db-password`) | tmpfs + etcd (K8s Secret `pulseauth-secrets`) |
| App reads via | File: `File.read("/mnt/secrets/db-password")` | Env var: `System.getenv("DB_PASSWORD")` |
| etcd involved | No ✅ | Yes ⚠️ |
| Spring Boot changes needed | Yes — custom `PropertySource` for file mapping | No — reads env vars natively |
| Compliance: zero etcd | Achievable | No — same as ESO |

The tradeoff is explicit. This folder uses `secretObjects` because:

1. Spring Boot reads env vars natively — zero app code change
2. The added etcd exposure is accepted as a secondary concern
3. The primary gain is still the ASCP/tmpfs pattern: no secret in Git, IRSA auth, CloudTrail audit

If strict compliance requires zero etcd — remove `secretObjects`, update all pods to read files instead of env vars, update Spring Boot config accordingly.

---

## Q9. The volume mount is not optional

This is the most operationally dangerous aspect of CSI + ASCP.

`pulseauth-secrets` (the K8s Secret) only exists because a pod with the volume mount starts successfully. No volume mount = ASCP never fetches = `pulseauth-secrets` never created.

```text
Scenario: you deploy postgres StatefulSet without the secrets-store volume mount

postgres-0 starts
  │
  ▼
Kubelet: no CSI volume mount requested
  │
  ▼
ASCP: never called
  │
  ▼
pulseauth-secrets: does not exist
  │
  ▼
postgres-0 tries envFrom: secretRef: pulseauth-secrets
  │
  ▼
CreateContainerConfigError: secret "pulseauth-secrets" not found
```

Every pod that needs env vars must also carry the volume mount, even if it doesn't read any files from `/mnt/secrets`. The mount is the trigger.

```yaml
# This block is REQUIRED on every pod — even if app doesn't read files
volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: pulseauth-secrets-provider
volumeMounts:
  - name: secrets-store
    mountPath: /mnt/secrets
    readOnly: true
```

→ [`k8s-manifests/04-postgres-statefulset.yaml`](./k8s-manifests/04-postgres-statefulset.yaml)
→ [`k8s-manifests/06-redis-deployment.yaml`](./k8s-manifests/06-redis-deployment.yaml)
→ [`k8s-manifests/08-pulseauth-deployment.yaml`](./k8s-manifests/08-pulseauth-deployment.yaml)

---

## IAM roles in this stack

| Role | Assumed by | Permissions |
| ---- | ---------- | ----------- |
| `eks-dev-cluster-role` | `eks.amazonaws.com` | EKS control plane operations |
| `eks-dev-node-role` | `ec2.amazonaws.com` | Join cluster, pull ECR, SSM |
| `pulseauth-ascp-role` | pulseauth SA via IRSA | `GetSecretValue` on exact ARN: `eks-secrets-dev/pulseauth/all`, `GetParameter` on `/eks-secrets-dev/pulseauth/*` |

---

## Terraform — secret shell + prevent_destroy

Same two-phase pattern as ESO, one secret instead of three:

```hcl
# terraform/modules/06_secrets_manager/main.tf
resource "aws_secretsmanager_secret" "pulseauth_all" {
  name = "eks-secrets-dev/pulseauth/all"
  lifecycle { prevent_destroy = true }
}
# no aws_secretsmanager_secret_version — no values in .tfstate
```

Seed after `terraform apply`:

```bash
aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/all \
  --region ap-south-1 \
  --secret-string '{
    "DB_HOST":        "postgres-svc",
    "DB_PORT":        "5432",
    "DB_NAME":        "pulseauth",
    "DB_USER":        "pulseadmin",
    "DB_PASSWORD":    "<your-db-password>",
    "REDIS_HOST":     "redis-svc",
    "REDIS_PORT":     "6379",
    "REDIS_PASSWORD": "<your-redis-password>",
    "MAIL_HOST":      "<smtp-host>",
    "MAIL_PORT":      "587",
    "MAIL_USER":      "<smtp-user>",
    "MAIL_PASSWORD":  "<smtp-password>",
    "MAIL_SMTP_AUTH": "true",
    "MAIL_SMTP_TLS":  "true"
  }'
```

**Cleanup sequence** (same `prevent_destroy` behavior as ESO):

```bash
# Step 1: delete secret manually
aws secretsmanager delete-secret \
  --secret-id eks-secrets-dev/pulseauth/all \
  --force-delete-without-recovery --region ap-south-1

# Step 2: remove from TF state
terraform state rm module.secrets_manager.aws_secretsmanager_secret.pulseauth_all

# Step 3: destroy succeeds
terraform destroy
```

→ [`terraform/modules/06_secrets_manager/main.tf`](./terraform/modules/06_secrets_manager/main.tf)

---

## ESO vs CSI — final decision matrix

```text
Situation                                           Use
──────────────────────────────────────────────────  ───────────────
App needs env vars, simplest integration            02 ESO
Team wants separate secrets per service             02 ESO
Compliance: no etcd exposure at all                 03 CSI + ASCP
Auto-refresh on rotation (no pod restart)           03 CSI + ASCP
PCI-DSS / HIPAA / SOC2 environment                  03 CSI + ASCP
Easier debugging (kubectl describe externalsecret)  02 ESO
Multiple secrets per namespace, scoped per app      02 ESO
Single consolidated secret, one mount               03 CSI + ASCP
```

Both use IRSA. Both use AWS Secrets Manager. Both eliminate hardcoded credentials. The difference is one architectural property: whether the secret value ever lands in etcd.

---

## Verdict

CSI + ASCP eliminates etcd from the secret lifecycle. The secret value lives in AWS SM, travels over IRSA-authenticated HTTPS to ASCP, and lands in pod RAM (tmpfs). Disk never involved. etcd never involved — unless `secretObjects` is used.

With `secretObjects` (this folder's approach): one step back toward etcd, but Spring Boot works without any app code changes. Explicit tradeoff, explicitly documented.

This is the production pattern for regulated environments. For everything else, ESO is simpler and sufficient.
