# Troubleshooting — 10_01 EKS RBAC + IAM

---

## Quick health check — run these first

```bash
# Overall pod health
kubectl get pods -n backend-prod
kubectl get pods -n external-secrets

# ESO sync status
kubectl get secretstore -n backend-prod
kubectl get externalsecret -n backend-prod

# Secrets created?
kubectl get secret -n backend-prod | grep pulseauth

# NLB up?
kubectl get svc pulseauth-svc -n backend-prod

# App logs
kubectl logs -n backend-prod -l app=pulseauth --tail=50
```

---

## Debug by symptom

### Pods stuck Pending

```bash
kubectl describe pod <pod-name> -n backend-prod
# look at Events section — usually FailedScheduling or FailedMount
```

PVC stuck Pending:

```bash
kubectl get pvc -n backend-prod
kubectl describe pvc postgres-data-postgres-0 -n backend-prod
kubectl logs -n kube-system -l app=ebs-csi-controller -c csi-provisioner --tail=30
```

### ESO not syncing secrets

```bash
kubectl describe secretstore pulseauth-secret-store -n backend-prod
kubectl describe externalsecret pulseauth-postgres-external-secret -n backend-prod

# Force re-sync (don't wait 1 hour)
kubectl annotate externalsecret pulseauth-postgres-external-secret \
  -n backend-prod force-sync=$(date +%s) --overwrite

kubectl annotate externalsecret pulseauth-mail-external-secret \
  -n backend-prod force-sync=$(date +%s) --overwrite
```

### App not starting / CrashLoopBackOff

```bash
kubectl logs -n backend-prod -l app=pulseauth --tail=100
kubectl describe pod -n backend-prod -l app=pulseauth
```

### RBAC validation scripts all DENIED

```bash
# Verify the profile is assuming the correct role
aws sts get-caller-identity --profile alice
# Should show: assumed-role/eks-rbac-dev-devops-admin-role/...

# Update kubeconfig for that role
$env:AWS_PROFILE = "alice"
aws eks update-kubeconfig --name eks-rbac-dev --region ap-south-1

# Manual test
kubectl auth can-i get pods -n backend-prod
```

### Frontend CORS errors (Registration failed)

```bash
# Check what origins CorsConfig.java allows
# File: pulseauth/backend/pulseauth/src/main/java/com/pulseauth/pulseauth/config/CorsConfig.java
# Must include the S3 website URL exactly:
# http://eks-rbac-dev-frontend.s3-website.ap-south-1.amazonaws.com

# After fixing, rebuild and push image, then restart:
kubectl rollout restart deployment/pulseauth -n backend-prod
```

---

## Gotchas

---

**PowerShell `$Args` is a reserved variable — splatting silently passes nothing**

All 7 `kubectl auth can-i` tests return DENIED even though the role exists and the access
entry is correct. The root cause is PowerShell's automatic `$Args` variable. When you
declare `param([string[]]$Args)` and splat it as `@Args`, PowerShell silently substitutes
the automatic empty `$Args` instead of your declared parameter. The kubectl command runs
with no arguments and returns `no` for every test.

Fix: rename the parameter to anything that isn't a PowerShell reserved word:

```powershell
# WRONG
param([string[]]$Args)
kubectl auth can-i @Args

# RIGHT
param([string[]]$KubectlArgs)
kubectl auth can-i @KubectlArgs
```

---

**`SecretStore` not found / `no matches for kind "SecretStore" in version "external-secrets.io/v1beta1"`**

ESO v4 dropped v1beta1. Any manifest using `apiVersion: external-secrets.io/v1beta1` for
`SecretStore` or `ExternalSecret` will fail with a "no matches for kind" error. The v4 API
version is `external-secrets.io/v1`.

Fix: change all ESO manifests:

```yaml
apiVersion: external-secrets.io/v1   # NOT v1beta1
kind: SecretStore
```

---

**ESO `InvalidProviderConfig: an IAM role must be associated with service account`**

The SecretStore uses JWT auth (IRSA), which requires the ServiceAccount to be annotated
with a role ARN and an OIDC provider to exist in IAM. If either is missing, ESO can't
exchange the SA token for AWS credentials.

Fix: three things must exist simultaneously:

```bash
# 1. OIDC provider in IAM (created by Terraform — verify it exists)
aws iam list-open-id-connect-providers

# 2. ServiceAccount annotation
kubectl get sa pulseauth-sa -n backend-prod -o yaml
# annotations:
#   eks.amazonaws.com/role-arn: arn:aws:iam::183295435445:role/eks-rbac-dev-pulseauth-eso-role

# 3. Role trust policy references the OIDC issuer
aws iam get-role --role-name eks-rbac-dev-pulseauth-eso-role --query Role.AssumeRolePolicyDocument
```

---

**Postgres `initdb: error: directory is not empty` / CrashLoopBackOff**

Fresh EBS volume has a `lost+found` directory at the root. Postgres refuses to init in a
non-empty directory. Without `subPath`, the entire EBS root is mounted at
`/var/lib/postgresql/data` and Postgres sees `lost+found` and aborts.

Fix: always mount with `subPath: pgdata`:

```yaml
volumeMounts:
  - name: postgres-data
    mountPath: /var/lib/postgresql/data
    subPath: pgdata    # Postgres gets its own subdirectory, lost+found stays at root
```

If the StatefulSet already exists without `subPath`, you must delete both the StatefulSet
and its PVC before reapplying — `volumeClaimTemplates` is immutable:

```bash
kubectl delete statefulset postgres -n backend-prod
kubectl delete pvc postgres-data-postgres-0 -n backend-prod
kubectl apply -f 05_test_workloads/postgres/statefulset.yaml
```

---

**Spring Boot `CrashLoopBackOff` — `UnknownHostException: postgres-svc`**

Spring Boot tries to connect to Postgres at startup. If Postgres isn't Ready yet, the
connection fails, Spring exits, Kubernetes restarts it, and the cycle repeats. The app
doesn't retry database connections on startup by default.

Fix: wait for Postgres to be fully ready before deploying the app. If the app is already
deployed, restart it after Postgres is up:

```bash
kubectl wait pod/postgres-0 -n backend-prod --for=condition=Ready --timeout=120s
kubectl rollout restart deployment/pulseauth -n backend-prod
```

---

**Users list shows stale "No users found" after registration**

`@Cacheable("users")` caches the empty user list on the first call. If `signup()` has no
`@CacheEvict`, the new user goes into Postgres but the cached empty list keeps being
returned until the cache TTL expires. The user "exists" but appears missing.

Fix: `UserService.signup()` and `verifyOtp()` must evict the cache:

```java
@CacheEvict(value = "users", allEntries = true)
public String signup(SignupRequest req) { ... }

@CacheEvict(value = {"users", "user"}, allEntries = true)
public String verifyOtp(String email, String otp) { ... }
```

After adding these annotations, rebuild the image and push to ECR. See deployment-steps.md
step 11.

---

**Registration fails with CORS error on POST (GET works fine)**

GET requests don't trigger CORS preflight. POST with `Content-Type: application/json`
does. If the backend's `CorsConfig` doesn't include the S3 origin, the preflight OPTIONS
request returns no CORS headers and the browser blocks the POST.

Fix: add the S3 website URL to `allowedOrigins` in `CorsConfig.java`:

```java
registry.addMapping("/api/**")
        .allowedOrigins(
                "http://localhost:4200",
                "http://eks-rbac-dev-frontend.s3-website.ap-south-1.amazonaws.com"
        )
        .allowedMethods("GET", "POST", "DELETE")
        .allowedHeaders("*");
```

Rebuild and push after this change. The S3 origin must match exactly — no trailing slash,
correct region, correct bucket name.

---

**`RedisConnectionFailureException: Unable to connect to Redis`**

Spring Boot crashes at startup because `redis-svc` doesn't exist. Redis isn't created by
ESO or Terraform — it needs its own Deployment and Service in `backend-prod`, which are
in `05_test_workloads/redis/` and must be applied explicitly.

Fix:

```bash
kubectl apply -f 05_test_workloads/redis/deployment.yaml
kubectl apply -f 05_test_workloads/redis/service.yaml

# Verify
kubectl get pods -n backend-prod -l app=redis
kubectl get svc redis-svc -n backend-prod
```

---

**EBS volume not deleted after `terraform destroy`**

PVCs with `reclaimPolicy: Retain` leave the underlying EBS volume behind even after the
PVC is deleted. `terraform destroy` has no knowledge of volumes created by the EBS CSI
driver — it only destroys what Terraform created. Retained volumes continue to incur cost.

Fix: delete the PVC before destroying, then check EC2 → Volumes manually:

```bash
kubectl delete pvc postgres-data-postgres-0 -n backend-prod
# Wait for PVC to disappear, then check AWS console
aws ec2 describe-volumes --filters Name=status,Values=available --region ap-south-1 \
  --query 'Volumes[*].{ID:VolumeId,Size:Size,State:State}'
# Delete any orphaned volumes
aws ec2 delete-volume --volume-id vol-xxxx --region ap-south-1
```
