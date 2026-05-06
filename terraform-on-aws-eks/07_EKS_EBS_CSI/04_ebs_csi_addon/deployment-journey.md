# Deployment Journey — Problems, Causes, and Fixes

Here are some questions I had in my mind while deploying this java application on EKS with EBS + ESO + IRSA.

---

### Why ESO at All? Why Not Just Call AWS Secrets Manager From the App?

This is the most important question to understand before anything else.

Imagine you're writing a Spring Boot app. Your app needs a DB password. The naive
approach: just call AWS SDK → `SecretsManager.GetSecretValue()` → parse JSON → use.

**That approach sounds simple. Here's what it costs you:**

```
Every app must bundle AWS SDK             --- heavier docker image, more dependencies
Every app must write secret-fetching code --- 50 lines of boilerplate in Java/ NodeJS/ Python - every time we have to writes the same thing

AWS Secrets Manager is temporarily down?  --- your app cannot start at all because it can't get its password
                                              on startup

Secret rotation (changing the password)?  --- app must detect the change, re-fetch, invalidate cache, handle race conditions
                                              this is notoriously hard to get right

Local development?                        --- developer needs AWS credentials on their laptop
                                              no AWS access = can't run the app at al
```

**ESO solves all of this by putting a layer between the app and AWS:**

```
ESO runs as a controller in the cluster.
It watches your ExternalSecret CRD.
It calls AWS Secrets Manager on behalf of your app.
It creates a normal Kubernetes Secret object.
Your application just reads environment variables. That's it.
```

**What the app sees with ESO:**

```
ums-app pod starts up:
  POSTGRES_DB       = umsdb         ---------------- just an env var, from k8s Secret
  POSTGRES_USER     = umsuser       ---------------- just an env var
  POSTGRES_PASSWORD = UmsP@ss#2024! ---------------- just an env var
```

App has no idea where these came from.
No AWS SDK. No secret-fetching code. No error handling for SM being down.

**The full comparison:**

```
WITHOUT ESO (app calls SM directly)        WITH ESO
──────────────────────────────────         ──────────────────────────────────
App has AWS SDK dependency                 App has ZERO AWS dependency
App has secret-fetching boilerplate        App reads env vars — 0 lines of code
SM down = app can't start                  SM down = k8s Secret still exists,
                                           app starts fine
Secret rotated = app must re-fetch         Secret rotated = ESO re-syncs
                                           automatically every 1h,
                                           app picks up on next restart
App only runs on AWS                       App runs on AWS, GCP, Azure,
                                           local minikube — identical behavior
New developer needs AWS creds              New developer creates a fake k8s Secret
to run the app locally                     locally — app works with zero AWS access
```

**This is why every serious Kubernetes deployment uses ESO or something like it.**
The app stays clean. AWS is an implementation detail that lives outside the app code.

---

## Step 1: Apply SecretStore and ExternalSecret Manifests

### What we ran
```bash
kubectl apply -f 03-postgres-secret-store.yaml
kubectl apply -f 04-postgres-externalsecret.yaml
```

### What happened
```
error: no matches for kind "SecretStore" in version "external-secrets.io/v1beta1"
ensure CRDs are installed first
```

### Why
Our YAML files were written for ESO v0.9.x which used `v1beta1`.
We installed ESO v4 which promoted everything to `v1`.
The API version in the files was outdated.

### Fix
Changed `apiVersion` in both files:
```yaml
# Before
apiVersion: external-secrets.io/v1beta1

# After
apiVersion: external-secrets.io/v1
```

---

## Step 4: SecretStore Said "IAM Role Must Be Associated"

### What we ran
```bash
kubectl apply -f 03-postgres-secret-store.yaml
kubectl get secretstore aws-secrets-manager -n ums-app
```

### What happened
```
STATUS: InvalidProviderConfig   READY: False
Message: an IAM role must be associated with service account ums-app-sa
```

### Why
The `SecretStore` was configured with JWT auth (IRSA pattern):
```yaml
auth:
  jwt:
    serviceAccountRef:
      name: ums-app-sa
```
This tells ESO: "use ums-app-sa's token to get AWS credentials via OIDC".

But two things were missing:
1. `ums-app-sa` had no annotation → ESO didn't know which IAM role to request
2. No OIDC provider existed in AWS IAM → STS couldn't validate the JWT

The role was set up for **Pod Identity** (different mechanism), not IRSA.

### Why We Changed to IRSA (not stayed with Pod Identity)

Pod Identity for ESO = bad idea:
- ESO controller is cluster-wide
- If you give ESO's SA a Pod Identity role, it has one role for ALL apps
- That role would need access to every app's secrets
- One compromise = attacker reads everything

IRSA = correct pattern for ESO:
- Each app's SA gets its own scoped role
- ESO reads ums-app-sa token → assumes ums-app-role → only ums/postgres secrets
- ESO controller itself has zero AWS permissions

### Fix — Three changes in Terraform

**1. Added OIDC provider:**
```hcl
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}
```

**2. Changed ums_app_role trust from Pod Identity → IRSA:**
```hcl
# Before (Pod Identity)
Principal = { Service = "pods.eks.amazonaws.com" }
Action    = ["sts:AssumeRole", "sts:TagSession"]

# After (IRSA)
Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
Action    = "sts:AssumeRoleWithWebIdentity"
Condition = {
  StringEquals = {
    "<oidc-url>:sub" = "system:serviceaccount:ums-app:ums-app-sa"
    "<oidc-url>:aud" = "sts.amazonaws.com"
  }
}
```

**3. Removed `aws_eks_pod_identity_association.ums_app`** from Terraform
(Pod Identity association for ums-app-sa no longer needed)

**4. Added IRSA annotation to `ums-app-sa`:**
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::183295435445:role/eks-public-dev-ums-app-role
```

Added `tls` provider to `backend.tf` and `providers.tf`, ran `terraform init`, then `terraform apply`.

---

## Step 5: ExternalSecret Still Failing — "key does not exist"

### What happened
After fixing IRSA, SecretStore went `Valid`. But ExternalSecret still errored:
```
error processing spec.data[0] (key: eks-public-dev/ums/postgres),
err: key POSTGRES_DB does not exist in secret eks-public-dev/ums/postgres
```

### Why
We had seeded the secret earlier but with **invalid JSON** — missing quotes:
```
{POSTGRES_DB:umsdb,POSTGRES_USER:umsuser,POSTGRES_PASSWORD:UmsP@ss#2024!}
```
ESO expects proper JSON to extract individual keys by property name.

### Fix
Re-seeded the secret with valid JSON:
```bash
aws secretsmanager put-secret-value \
  --secret-id eks-public-dev/ums/postgres \
  --region ap-south-1 \
  --secret-string '{"POSTGRES_DB":"umsdb","POSTGRES_USER":"umsuser","POSTGRES_PASSWORD":"UmsP@ss#2024!"}'
```

Then force-triggered ESO to re-sync immediately (instead of waiting 1 hour):
```bash
kubectl annotate externalsecret postgres-external-secret \
  -n ums-app force-sync=$(date +%s) --overwrite
```

Result: `SecretSynced True` — `postgres-secret` k8s Secret created with 3 keys.

---

## Step 6: Postgres Pod CrashLoopBackOff — "directory is not empty"

### What we saw
```
postgres-0   0/1   CrashLoopBackOff
```

### Logs
```
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
initdb: detail: It contains a lost+found directory, perhaps due to it being a mount point.
initdb: hint: Using a mount point directly as the data directory is not recommended.
```

### Why
When AWS creates a fresh EBS volume and mounts it, the filesystem has a `lost+found`
directory at the root. Postgres's `initdb` sees this and refuses to initialize —
it thinks the data directory is already used by something else.

This is a very common gotcha with EBS + Postgres on Kubernetes.

### Fix
Added `subPath: pgdata` to the volume mount:
```yaml
volumeMounts:
  - name: postgres-data
    mountPath: /var/lib/postgresql/data
    subPath: pgdata   ← postgres writes to /pgdata/ inside the EBS volume
                        lost+found stays at root, postgres never sees it
```

Because StatefulSet `volumeClaimTemplates` can't be patched in-place,
we deleted the StatefulSet and PVC, then reapplied:
```bash
kubectl delete statefulset postgres -n ums-app
kubectl delete pvc postgres-data-postgres-0 -n ums-app
kubectl apply -f 06-postgres-statefulset.yaml
```

Postgres initialized cleanly and came up `Running`.

---

## Step 7: ums-app CrashLoopBackOff — "UnknownHostException: postgres-svc"

### What we saw
```
ums-app-xxx   0/1   CrashLoopBackOff
```

### Logs
```
Caused by: java.net.UnknownHostException: postgres-svc
```

### Why
The ums-app pods had started before postgres was ready (the StatefulSet had just been
recreated). Spring Boot with HikariCP tries to connect to the database at startup.
When it can't connect within its timeout, it crashes.

This wasn't a DNS or networking problem — `postgres-svc` was correct. Postgres just
wasn't ready yet when ums-app tried to connect.

### Fix
Restarted the ums-app deployment after postgres was confirmed Running:
```bash
kubectl rollout restart deployment/ums-app -n ums-app
```

New pods came up, postgres was ready, connections succeeded.

---

## Final State

```bash
kubectl get pods -n ums-app

NAME                       READY   STATUS    RESTARTS
postgres-0                 1/1     Running   0
ums-app-69d7d6c4d8-l54ch   1/1     Running   0
ums-app-69d7d6c4d8-wkd2q   1/1     Running   0
```

```bash
kubectl get externalsecret -n ums-app

NAME                       STATUS         READY   LAST SYNC
postgres-external-secret   SecretSynced   True    ...
```

Everything green.

---

## Quick Reference — Commands We Used

```bash
# Install ESO
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace --wait

# Apply all manifests in order
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-storageclass.yaml
kubectl apply -f 02-ums-serviceaccount.yaml
kubectl apply -f 03-postgres-secret-store.yaml
kubectl apply -f 04-postgres-externalsecret.yaml
kubectl apply -f 05-postgres-configmap.yaml
kubectl apply -f 06-postgres-statefulset.yaml
kubectl apply -f 07-postgres-service.yaml
kubectl apply -f 08-ums-configmap.yaml
kubectl apply -f 09-ums-deployment.yaml
kubectl apply -f 10-ums-service.yaml

# Seed the real secret (run once after terraform apply)
aws secretsmanager put-secret-value \
  --secret-id eks-public-dev/ums/postgres \
  --region ap-south-1 \
  --secret-string '{"POSTGRES_DB":"umsdb","POSTGRES_USER":"umsuser","POSTGRES_PASSWORD":"YourPass"}'

# Force ESO to re-sync immediately
kubectl annotate externalsecret postgres-external-secret \
  -n ums-app force-sync=$(date +%s) --overwrite

# Check everything
kubectl get pods -n ums-app
kubectl get secretstore -n ums-app
kubectl get externalsecret -n ums-app
kubectl get secret postgres-secret -n ums-app
kubectl logs postgres-0 -n ums-app
kubectl logs deployment/ums-app -n ums-app

# Restart ums-app (e.g. after postgres restarts)
kubectl rollout restart deployment/ums-app -n ums-app

# Fix StatefulSet volumeClaimTemplate (delete + recreate)
kubectl delete statefulset postgres -n ums-app
kubectl delete pvc postgres-data-postgres-0 -n ums-app
kubectl apply -f 06-postgres-statefulset.yaml
```

---

## Lessons Learned

| Problem | Root Cause | Remember |
|---------|-----------|---------|
| `v1beta1` not found | ESO v4 uses `v1` | Check API versions match ESO version installed |
| SecretStore not ready | No IRSA annotation + no OIDC provider | IRSA needs both: annotation on SA + OIDC provider in AWS IAM |
| Key does not exist | Secret stored as invalid JSON (no quotes) | Always use `'{"key":"value"}'` format, verify with `aws secretsmanager get-secret-value` |
| Postgres won't init | EBS volume has `lost+found` at root | Always use `subPath` with EBS + Postgres |
| ums-app can't connect | Started before postgres was ready | After recreating StatefulSet, restart dependent deployments |
