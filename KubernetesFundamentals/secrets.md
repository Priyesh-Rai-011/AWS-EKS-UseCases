# Kubernetes Secrets — The Concept Layer

Your app needs a database password. Where does it live?

Not in code. Not in a ConfigMap. Not in a Deployment YAML.
This document is about why — and what Kubernetes actually gives you.

For the AWS implementation (ESO, CSI, ASCP) → [`09_EKS_Secrets_Management/`](../terraform-on-aws-eks/09_EKS_Secrets_Management/)

---

## Q1. Why does `kind: Secret` exist separately from `kind: ConfigMap`?

ConfigMap and Secret look almost identical in YAML. Both hold key-value data. Both get injected into pods. So why two objects?

The split is intentional. ConfigMap = non-sensitive configuration (ports, hostnames, feature flags). Secret = anything that grants access (passwords, tokens, TLS certs, API keys). Kubernetes treats them differently at the API layer — RBAC policies can allow a developer to read ConfigMaps but not Secrets. The object boundary IS the security boundary.

```text
ConfigMap  →  DB_HOST, APP_PORT, REDIS_HOST, LOG_LEVEL
Secret     →  DB_PASSWORD, REDIS_PASSWORD, JWT_SECRET, TLS_KEY
```

Both exist side by side in every real deployment. Secret doesn't replace ConfigMap.

---

## Q2. Are Kubernetes Secrets actually encrypted?

No. This is the most common misconception.

```bash
kubectl get secret postgres-secret -n pulseauth -o yaml
```

```yaml
data:
  DB_PASSWORD: bXlwYXNzd29yZA==
```

That value is base64 encoded. Run `echo "bXlwYXNzd29yZA==" | base64 -d` and you get `mypassword` back instantly. Base64 is encoding, not encryption. Anyone with `kubectl get secret` permission reads the value in plain text.

```text
base64 encode:  "mypassword"  →  "bXlwYXNzd29yZA=="
base64 decode:  "bXlwYXNzd29yZA=="  →  "mypassword"

This is reversible by anyone with a terminal.
It is NOT encryption.
```

---

## Q3. Where does the secret physically live?

etcd. The control plane's key-value database.

```
kubectl apply -f secret.yaml
        │
        ▼
API Server validates + stores
        │
        ▼
etcd (disk, on control plane node)
        │
        ▼
Kubelet reads it when scheduling pod
        │
        ▼
Pod gets secret injected
```

etcd is a file on disk. If an attacker gets access to the control plane, they get every secret in the cluster. In managed EKS, AWS controls the control plane — you can't SSH into it. But in self-hosted Kubernetes, etcd access = full secret exposure.

**Encryption at rest** is a separate etcd config that encrypts the data before writing to disk. It is not enabled by default in many distributions. Even when enabled, it encrypts against disk access — not against someone with valid kubeconfig.

---

## Q4. Who else in the cluster can read my secret?

Anyone with the right RBAC Role. And the defaults are looser than you think.

```yaml
# This Role allows reading all secrets in the namespace
kind: Role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
```

Without explicit RBAC lockdown, any pod with a mounted ServiceAccount token (default behavior) can call the API server and list secrets in its namespace. This is why namespace isolation matters — it's your blast radius boundary.

```
Namespace A secrets  →  only visible to pods/roles in Namespace A
Namespace B secrets  →  only visible to pods/roles in Namespace B

No namespace =  default namespace =  everything sees everything
```

---

## Q5. How does a pod consume a secret?

Two patterns. They behave differently.

**Pattern 1 — Environment variable injection:**

```yaml
envFrom:
- secretRef:
    name: postgres-secret      # all keys become env vars

# or per-key:
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: DB_PASSWORD
```

Value is read once at pod startup. Secret rotates in etcd → pod still has the old value until it restarts.

**Pattern 2 — Volume mount:**

```yaml
volumes:
- name: secrets-vol
  secret:
    secretName: postgres-secret

volumeMounts:
- name: secrets-vol
  mountPath: /etc/secrets
  readOnly: true
```

Secret is a file at `/etc/secrets/DB_PASSWORD`. Kubelet watches for updates and can refresh the file without pod restart (with some latency). Safer for rotation. Preferred for TLS certs.

```
env var injection  →  read once at startup, stale after rotation
volume mount       →  file on tmpfs, refreshable, preferred for certs
```

---

## Q6. What are the production limits of native K8s Secrets?

Four hard problems:

**1. etcd exposure** — secret values live on the control plane. Anyone with cluster admin can read everything.

**2. No audit trail** — who read this secret, when? Native secrets have no access log at the secret level.

**3. Rotation is manual** — you update the Secret object, then restart pods. Nothing is automatic.

**4. No centralized management** — 3 clusters (dev/staging/prod) means 3 separate Secret objects to keep in sync. Rotate once, update three times, hope you didn't miss one.

```
Problem                 Native K8s Secret       External Secret Manager
─────────────────────   ─────────────────────   ───────────────────────
Source of truth         etcd (in cluster)       AWS SM (outside cluster)
Audit trail             none                    full CloudTrail log
Rotation                manual restart          automatic sync
Multi-cluster sync      manual                  one secret, many clusters
etcd exposure           YES                     YES (ESO) / NO (CSI)
```

The last row is the key one. Even with ESO, the secret still lands in etcd. Eliminating that requires the CSI approach.

**This is exactly why production teams move secrets outside Kubernetes.**

→ How ESO solves the source-of-truth problem: [`02_external_secrets_operator/`](../terraform-on-aws-eks/09_EKS_Secrets_Management/02_external_secrets_operator/)

→ How CSI eliminates etcd entirely: [`03_csi_driver_ascp/`](../terraform-on-aws-eks/09_EKS_Secrets_Management/03_csi_driver_ascp/)
