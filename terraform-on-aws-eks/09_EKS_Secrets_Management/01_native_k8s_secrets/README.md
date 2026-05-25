# 01 — Native Kubernetes Secrets

Kubernetes has a built-in object for secrets. It works. Every cluster has it. No extra tools required.

This folder uses it for PulseAuth (Spring Boot + Postgres + Redis + Mail). The goal is not to show the right way — it's to show exactly where the built-in approach breaks, so the next two folders make sense.

---

## Questions

- [Why does `kind: Secret` exist separately from `kind: ConfigMap`?](#q1-why-does-kind-secret-exist-separately-from-kind-configmap)
- [Is base64 encryption?](#q2-is-base64-encryption)
- [Where does the secret physically live?](#q3-where-does-the-secret-physically-live)
- [Who else in the cluster can read this secret?](#q4-who-else-in-the-cluster-can-read-this-secret)
- [env var vs volume mount — which is safer?](#q5-env-var-vs-volume-mount--which-is-safer)
- [What breaks in production with native secrets?](#q6-what-breaks-in-production-with-native-secrets)

---

## Folder structure

```text
01_native_k8s_secrets/
├── terraform/
│   ├── main.tf                     ← wires vpc + eks + bastion + ecr modules
│   ├── variables.tf
│   ├── locals.tf
│   ├── backend.tf                  ← remote state: s3://learning-remotebackend2
│   ├── provider.tf
│   └── modules/
│       ├── 01_vpc/                 ← VPC, subnets, NAT GW, route tables
│       ├── 02_eks/                 ← EKS cluster, node group, OIDC provider
│       ├── 03_bastion/             ← EC2 bastion, SSM access, kubectl bootstrap
│       └── 04_ecr/                 ← ECR repository for pulseauth image
│
└── k8s-manifests/
    ├── 00-namespace.yaml           ← ns: pulseauth
    ├── 01-storageclass.yaml        ← ebs-gp3-sc (for postgres PVC)
    ├── 02-secrets.yaml             ← kubectl commands only, no values in file
    ├── 03-postgres-statefulset.yaml
    ├── 04-postgres-service.yaml    ← ClusterIP headless
    ├── 05-redis-deployment.yaml
    ├── 06-redis-service.yaml       ← ClusterIP
    ├── 07-pulseauth-deployment.yaml
    └── 08-pulseauth-service.yaml   ← LoadBalancer (NLB)
```

---

## Q1. Why does `kind: Secret` exist separately from `kind: ConfigMap`?

Every app has two kinds of config: things that are sensitive (passwords, tokens) and things that are not (hostnames, ports, feature flags). Kubernetes splits them into two objects so RBAC can treat them differently. A developer can read ConfigMaps without being able to read Secrets.

```text
ConfigMap  →  DB_HOST=postgres-svc, DB_PORT=5432, REDIS_HOST=redis-svc
Secret     →  DB_PASSWORD=..., REDIS_PASSWORD=..., MAIL_PASSWORD=...
```

In this folder, PulseAuth uses both. The `Deployment` and `StatefulSet` manifests pull non-sensitive config from a ConfigMap and credentials from Secrets via `envFrom`.

→ [`k8s-manifests/07-pulseauth-deployment.yaml`](./k8s-manifests/07-pulseauth-deployment.yaml)

---

## Q2. Is base64 encryption?

No. This is important enough to say twice.

```bash
echo "bXlwYXNzd29yZA==" | base64 -d
# outputs: mypassword
```

```bash
kubectl get secret pulseauth-db-secret -n pulseauth -o yaml
# shows DB_PASSWORD: bXlwYXNzd29yZA==
# anyone with kubectl access decodes it in one command
```

base64 is encoding — a reversible transformation for safe transport over text protocols. It is not encryption. There is no key. There is no protection. Anyone who can call `kubectl get secret` reads the value immediately.

Kubernetes documentation itself says: *"Kubernetes Secrets are, by default, stored unencrypted."*

---

## Q3. Where does the secret physically live?

etcd. The control plane's key-value database.

```text
kubectl create secret generic pulseauth-db-secret ...
        │
        ▼
API Server receives the request
        │
        ▼
Writes to etcd  (base64 encoded, on control plane disk)
        │
        ▼
Kubelet reads from API Server when scheduling the pod
        │
        ▼
Pod gets DB_PASSWORD injected as env var
```

In EKS, AWS manages the control plane — you cannot SSH into the etcd node. But etcd encryption at rest is not enabled by default. Anyone who compromises the control plane, or gets an admin kubeconfig, reads every secret in the cluster without any further access.

**The real weakness is not the pod. The real weakness is etcd.**

---

## Q4. Who else in the cluster can read this secret?

Anyone with a Role that grants `get` on `secrets` in the `pulseauth` namespace. And by default, the service account token mounted in every pod can potentially be used to call the API server.

```yaml
# This is all it takes to read every secret in the namespace
kind: Role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

Namespace isolation is your blast radius boundary. A secret in `pulseauth` is not visible to pods in `kube-system` — but only if RBAC is correctly scoped. Default service account permissions vary by cluster configuration.

In this folder, three separate K8s Secrets are created:

```text
pulseauth-db-secret     →  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
pulseauth-redis-secret  →  REDIS_HOST, REDIS_PORT, REDIS_PASSWORD
pulseauth-mail-secret   →  MAIL_HOST, MAIL_PORT, MAIL_USER, MAIL_PASSWORD, MAIL_SMTP_AUTH, MAIL_SMTP_TLS
```

Separation is intentional — postgres StatefulSet only gets `pulseauth-db-secret`, not mail credentials it has no business reading.

→ [`k8s-manifests/02-secrets.yaml`](./k8s-manifests/02-secrets.yaml) (documents the `kubectl create secret` commands)

---

## Q5. env var vs volume mount — which is safer?

Both are used in practice. They behave differently in two ways that matter.

**env var (`envFrom`):**

```yaml
envFrom:
- secretRef:
    name: pulseauth-db-secret
```

Value is read once at pod startup and held in the process environment. If the secret rotates in etcd, the pod still has the old value until it restarts. Environment variables also appear in crash dumps, `kubectl exec` output, and some logging systems.

**Volume mount:**

```yaml
volumes:
- name: secrets-vol
  secret:
    secretName: pulseauth-db-secret
volumeMounts:
- name: secrets-vol
  mountPath: /etc/secrets
  readOnly: true
```

Secret is a file. Kubelet can refresh the file without pod restart (with some latency). Preferred for TLS certificates that rotate. Does not appear in environment variable dumps.

This folder uses `envFrom` — simpler, sufficient for the learning exercise. Production favors volume mounts for credentials that rotate.

---

## Q6. What breaks in production with native secrets?

Four problems that hit real teams:

**1. No audit trail.** Who read `pulseauth-db-secret`? When? From which pod? Native K8s Secrets have no per-read logging. You get API server audit logs if you configure them, but not secret-level access tracking.

**2. Rotation is manual.** Database password changes → update the Secret object → restart every pod that uses it. In a multi-cluster setup (dev/staging/prod), that's three separate `kubectl` operations. Miss one and production runs with a stale password.

**3. Secret values are in etcd.** The value physically lives in the cluster. Backup your etcd? The secret is in the backup. Snapshot the cluster? The secret is in the snapshot. The blast radius of a cluster compromise includes your credentials.

**4. Terraform cannot safely manage values.** `.tfstate` is plaintext JSON stored in S3. If Terraform creates the Secret with the real password, that password is now in your state file forever. This folder's Terraform code does not manage the secret values — only the infrastructure. Credentials are created via `kubectl create secret` directly on the bastion.

```text
Problem                    Native K8s approach
─────────────────────────  ───────────────────────────────────
Source of truth            etcd (inside the cluster)
Audit trail                none at secret level
Rotation                   manual kubectl + pod restart
Multi-cluster sync         manual — 3 clusters = 3 updates
etcd exposure              yes, always
Terraform safe?            no — values would land in .tfstate
```

These are the exact problems ESO solves. Not because ESO is fashionable — because each of these failure modes is a real production incident waiting to happen.

---

## Architecture

```text
  kubectl create secret
          │
          ▼
  ┌──────────────────────────────────────────────────────┐
  │  Kubernetes Control Plane                             │
  │                                                       │
  │  API Server ──▶ etcd  (base64, on disk, no KMS)      │
  └────────────────────────┬─────────────────────────────┘
                           │  Kubelet reads on pod schedule
                           ▼
              ┌────────────────────────┐
              │  Worker Node           │
              │  Kubelet injects       │
              │  env vars into pod     │
              └────────────┬───────────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │  postgres    │  │  redis       │  │  pulseauth   │
  │  StatefulSet │  │  Deployment  │  │  Deployment  │
  │  (DB_*)      │  │  (REDIS_*)   │  │  (all 3)     │
  └──────────────┘  └──────────────┘  └──────────────┘
```

No AWS involved. No IRSA. No external tooling. Just `kubectl` and etcd.

---

## Deployment steps

```bash
# 1. Terraform — provision VPC, EKS, bastion, ECR
cd terraform/
terraform init && terraform plan && terraform apply

# 2. Configure kubectl (run on bastion via SSM)
aws eks update-kubeconfig --region ap-south-1 --name <cluster-name>

# 3. Apply namespace + storageclass first
kubectl apply -f k8s-manifests/00-namespace.yaml
kubectl apply -f k8s-manifests/01-storageclass.yaml

# 4. Create secrets imperatively — never in YAML files
kubectl create secret generic pulseauth-db-secret -n pulseauth \
  --from-literal=DB_HOST=postgres-svc \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=pulseauth \
  --from-literal=DB_USER=pulseadmin \
  --from-literal=DB_PASSWORD=<your-password>

kubectl create secret generic pulseauth-redis-secret -n pulseauth \
  --from-literal=REDIS_HOST=redis-svc \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=REDIS_PASSWORD=<your-redis-password>

kubectl create secret generic pulseauth-mail-secret -n pulseauth \
  --from-literal=MAIL_HOST=<smtp-host> \
  --from-literal=MAIL_PORT=587 \
  --from-literal=MAIL_USER=<smtp-user> \
  --from-literal=MAIL_PASSWORD=<smtp-password> \
  --from-literal=MAIL_SMTP_AUTH=true \
  --from-literal=MAIL_SMTP_TLS=true

# 5. Apply remaining manifests in order
kubectl apply -f k8s-manifests/03-postgres-statefulset.yaml
kubectl apply -f k8s-manifests/04-postgres-service.yaml
kubectl wait --for=condition=Ready pod/postgres-0 -n pulseauth --timeout=120s
kubectl apply -f k8s-manifests/05-redis-deployment.yaml
kubectl apply -f k8s-manifests/06-redis-service.yaml
kubectl apply -f k8s-manifests/07-pulseauth-deployment.yaml
kubectl apply -f k8s-manifests/08-pulseauth-service.yaml

# 6. Verify
kubectl get pods,svc,secret -n pulseauth
```

---

## Gotchas

**Secret created after pod — pod crashes with `CreateContainerConfigError`**

Pod starts, Kubernetes tries to inject env vars from `pulseauth-db-secret`, secret doesn't exist yet, pod fails. Always create secrets before applying StatefulSet/Deployment manifests.

**`kubectl create secret` fails — namespace doesn't exist**

Apply `00-namespace.yaml` first. `kubectl create secret` does not auto-create the namespace.

**postgres `initdb: error: directory is not empty`**

Fresh EBS volume has a `lost+found` directory at the root. Postgres refuses to initialize a non-empty directory. Fix: `subPath: pgdata` on the volume mount — already present in `03-postgres-statefulset.yaml`.

→ [`k8s-manifests/03-postgres-statefulset.yaml`](./k8s-manifests/03-postgres-statefulset.yaml)

### Terraform destroy — EBS volume not deleted

PVC has `reclaimPolicy: Retain`. Terraform destroy removes the cluster but not the EBS volume. Check EC2 → Volumes in the AWS console and delete manually.

---

## Verdict

Native K8s Secrets work. For a learning environment or non-sensitive config, they're fine.

For production credentials:

- Values live in etcd — cluster compromise = credential exposure
- No audit trail — you don't know who read what
- Rotation is fully manual
- Terraform cannot manage values without leaking them to `.tfstate`

The next folder moves the source of truth outside the cluster entirely.

→ [`02_external_secrets_operator/`](../02_external_secrets_operator/)
