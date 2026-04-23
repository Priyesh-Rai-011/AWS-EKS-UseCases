# EBS CSI Driver Troubleshooting

---

## PVC Stuck in Pending

**Symptom:** `kubectl get pvc -n ums-app` shows `STATUS: Pending` indefinitely.

**Check 1 — PVC events:**

```bash
kubectl describe pvc mysql-pvc -n ums-app
```

Look for `FailedProvision` or `no nodes available` in events.

**Check 2 — CSI controller pods running:**

```bash
kubectl get pods -n kube-system | grep ebs-csi
```

Expected output:

```text
ebs-csi-controller-xxxx   6/6   Running
ebs-csi-node-xxxx         3/3   Running   (one per node)
```

**Check 3 — StorageClass exists:**

```bash
kubectl get storageclass
```

Must see `ebs-gp3-sc` with provisioner `ebs.csi.aws.com`.

**Fix:** If no StorageClass, apply it:

```bash
kubectl apply -f k8s-manifests/01-storage-class.yaml
```

---

## EBS CSI Controller CrashLoopBackOff

**Symptom:** `ebs-csi-controller` pod keeps restarting.

**Check logs:**

```bash
kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin
```

**Common causes:**

### IAM permissions denied

Log shows: `UnauthorizedOperation` or `AccessDenied`.

**Addon approach fix** — verify Pod Identity Association exists:

```bash
aws eks list-pod-identity-associations --cluster-name <cluster-name>
```

**Helm approach fix** — verify IRSA annotation on ServiceAccount:

```bash
kubectl get sa ebs-csi-controller-sa -n kube-system -o yaml | grep role-arn
```

Expected:

```text
eks.amazonaws.com/role-arn: arn:aws:iam::<account>:role/<cluster>-ebs-csi-role
```

If missing, re-run `terraform apply` — Helm release should patch the annotation.

### OIDC provider missing (Helm / IRSA only)

Log shows: `InvalidIdentityToken`.

Check OIDC provider exists:

```bash
aws iam list-open-id-connect-providers
```

Must match the cluster's OIDC issuer URL. If missing, `terraform apply` recreates it via `aws_iam_openid_connect_provider`.

---

## MySQL Pod Stuck in Init / CrashLoopBackOff

**Symptom:** MySQL pod not starting, PVC shows `Bound` but pod fails.

**Check 1 — Pod events:**

```bash
kubectl describe pod -l app=mysql -n ums-app
```

**Check 2 — EBS volume actually attached:**

```bash
kubectl get volumeattachment
```

**Common cause — wrong AZ:** EBS volumes are AZ-scoped. StorageClass must use `WaitForFirstConsumer` so the volume is created in the same AZ as the scheduled node.

Verify StorageClass binding mode:

```bash
kubectl get storageclass ebs-gp3-sc -o yaml | grep bindingMode
```

Must be `WaitForFirstConsumer`, not `Immediate`.

---

## UMS App Cannot Connect to MySQL

**Symptom:** UMS pods running but returning 500 errors. Logs show `Communications link failure`.

**Check 1 — MySQL service reachable:**

```bash
kubectl exec -it <ums-pod> -n ums-app -- curl mysql-svc:3306
```

**Check 2 — ConfigMap has correct DB_URL:**

```bash
kubectl get configmap ums-config -n ums-app -o yaml
```

Must show:

```yaml
DB_URL: jdbc:mysql://mysql-svc:3306/umsdb
```

**Check 3 — Secret keys match:**

```bash
kubectl get secret mysql-secret -n ums-app -o jsonpath='{.data}' | base64 -d
```

Keys must be `MYSQL_USER` and `MYSQL_PASSWORD` (exact case — Deployment references these).

---

## Helm Release Fails During Terraform Apply

**Symptom:** `terraform apply` errors on `helm_release.ebs_csi_driver`.

### Error: cannot connect to cluster

```text
Error: Kubernetes cluster unreachable
```

Cause: Helm provider configured before cluster is ready. Fix: ensure `depends_on = [module.eks]` is set on the `ebs_csi` module call in `main.tf`.

### Error: release already exists

```text
Error: cannot re-use a name that is still in use
```

Cause: previous manual `helm install` left a release. Fix:

```bash
helm uninstall aws-ebs-csi-driver -n kube-system
terraform apply
```

---

## Terraform Init Errors

**Duplicate output definition:**

```text
Error: Duplicate output definition
```

Cause: same output name defined in two `.tf` files within same module. Each module scope must have unique output names across all files. Remove the duplicate.

**Security group description invalid characters:**

```text
"description" doesn't comply with restrictions
("^[0-9A-Za-z_ .:/()#,@\[\]+=&;{}!$*-]*$")
```

Cause: em dash `—` or other Unicode in `description` field of `aws_security_group` or `ingress` block. AWS API only accepts ASCII subset. Replace `—` with `-`.

---

## Useful Debug Commands

```bash
# All pods across namespaces
kubectl get pods -A

# EBS CSI controller logs (ebs-plugin container)
kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin --tail=50

# PVC + PV status
kubectl get pvc,pv -n ums-app

# Check node has EBS CSI node DaemonSet running
kubectl get pods -n kube-system -l app=ebs-csi-node -o wide

# Describe a stuck pod
kubectl describe pod <pod-name> -n ums-app

# Check IAM role trust policy (IRSA)
aws iam get-role --role-name <cluster>-ebs-csi-role --query 'Role.AssumeRolePolicyDocument'

# Verify kubectl context points to right cluster
kubectl config current-context
aws eks update-kubeconfig --region ap-south-1 --name eks-helm-dev
```
