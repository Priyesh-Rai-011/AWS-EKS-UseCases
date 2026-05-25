# Troubleshooting

## Quick health check

```bash
kubectl get pods,svc,pvc -n pulseauth
kubectl get secretstore,externalsecret -n pulseauth
kubectl get pods -n external-secrets
```

---

## Debug by symptom

**ExternalSecret stuck / not syncing**
```bash
kubectl describe externalsecret pulseauth-db-external-secret -n pulseauth
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50

# Force re-sync without waiting 1h
kubectl annotate externalsecret pulseauth-db-external-secret \
  -n pulseauth force-sync=$(date +%s) --overwrite
```

**PVC stuck Pending**
```bash
kubectl describe pvc postgres-data-postgres-0 -n pulseauth
kubectl logs -n kube-system -l app=ebs-csi-controller -c csi-provisioner --tail=30
kubectl get pods -n kube-system | grep ebs-csi
```

**postgres-0 CrashLoopBackOff**
```bash
kubectl logs postgres-0 -n pulseauth --previous
```

**pulseauth can't connect to postgres**
```bash
kubectl exec -it deploy/pulseauth -n pulseauth -- sh
# inside pod:
curl postgres-svc:5432     # connection refused = network OK, postgres down
                           # timeout = DNS or network problem
```

**IRSA not working / ESO can't assume role**
```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep role-arn
aws iam list-open-id-connect-providers --region us-east-1
aws iam get-role --role-name external-secrets-operator-role --query Role.AssumeRolePolicyDocument
```

---

## Gotchas

---

**SecretStore STATUS: InvalidProviderConfig — "IAM role must be associated with service account"**

Two things must exist at the same time: the OIDC provider in AWS IAM, and the IRSA annotation on the ESO service account. Terraform creates the OIDC provider. The SA annotation is a manual step — it's the one thing that bridges the two.

```bash
kubectl annotate serviceaccount external-secrets \
  -n external-secrets \
  eks.amazonaws.com/role-arn=$(cd terraform && terraform output -raw eso_role_arn) \
  --overwrite
kubectl annotate externalsecret pulseauth-db-external-secret \
  -n pulseauth force-sync=$(date +%s) --overwrite
```

---

**ExternalSecret STATUS: SecretSyncError — "key does not exist"**

Secret was seeded with invalid JSON — no quotes around keys or values. ESO parses the JSON to extract individual properties. If the JSON is malformed, every property lookup fails.

```bash
# Verify what's actually stored
aws secretsmanager get-secret-value \
  --secret-id eks-secrets-dev/pulseauth/postgres \
  --region us-east-1 --query SecretString --output text

# Reseed with valid JSON
aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/postgres \
  --region us-east-1 \
  --secret-string '{"DB_HOST":"postgres-svc","DB_PORT":"5432","DB_NAME":"pulseauth","DB_USER":"pulseadmin","DB_PASSWORD":"YourPass"}'

kubectl annotate externalsecret pulseauth-db-external-secret \
  -n pulseauth force-sync=$(date +%s) --overwrite
```

---

**PVC stuck Pending — no error in describe output**

EBS CSI driver isn't installed. The StorageClass uses `provisioner: ebs.csi.aws.com` — if that driver isn't running, PVC requests silently sit forever. The describe output won't tell you why.

```bash
kubectl get pods -n kube-system | grep ebs-csi
# No output = driver not installed
```

Install it — see Step 3 in [deployment-steps.md](deployment-steps.md).

---

**postgres-0 CrashLoopBackOff — "initdb: directory is not empty" / "lost+found"**

Fresh EBS volume has a `lost+found` directory at filesystem root. Postgres initdb refuses to initialize because the data directory isn't empty. `subPath: pgdata` is already in the StatefulSet manifest — if you hit this, it got removed somehow.

```bash
kubectl delete statefulset postgres -n pulseauth
kubectl delete pvc postgres-data-postgres-0 -n pulseauth
kubectl apply -f 07-postgres-statefulset.yaml
# Verify subPath: pgdata is present in the volumeMount before applying
```

---

**pulseauth CrashLoopBackOff — "Connection refused" to postgres-svc**

Pulseauth started before postgres was Ready. Spring Boot + HikariCP tries to connect at startup. If postgres isn't up yet, it fails and crashes. Not a DNS or networking problem — postgres just wasn't ready.

```bash
# Confirm postgres is Running 1/1 first
kubectl get pods -n pulseauth | grep postgres
# Then restart pulseauth
kubectl rollout restart deployment/pulseauth -n pulseauth
```

---

**ESO IAM role has Resource: "\*" for Secrets Manager**

`modules/05_eso_iam/main.tf` uses a wildcard resource. ESO can read any secret in the entire AWS account. Fine for dev/learning, wrong for production.

Scope it down in the role policy:
```hcl
Resource = "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:eks-secrets-dev/pulseauth/*"
```

---

**02-serviceaccount.yaml has `<ESO_ROLE_ARN_PLACEHOLDER>` literally**

The ARN is only known after `terraform apply`. The file ships as a template.

```bash
sed -i "s|<ESO_ROLE_ARN_PLACEHOLDER>|$(cd ../terraform && terraform output -raw eso_role_arn)|" \
  02-serviceaccount.yaml
kubectl apply -f 02-serviceaccount.yaml
```
