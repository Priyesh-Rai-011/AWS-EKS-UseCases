# Install Order — 02_external_secrets_operator

## Step 1: Terraform apply

```bash
cd terraform/
terraform init
terraform apply
```

Note the ESO role ARN from output:
```bash
terraform output eso_role_arn
```

## Step 2: Install ESO via Helm

ESO creates its own ServiceAccount. Annotate it with the IAM role ARN at install time.

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<ESO_ROLE_ARN>
```

Wait for ESO controller to be Running:
```bash
kubectl get pods -n external-secrets
```

## Step 3: Seed secrets in AWS Secrets Manager

`terraform apply` already created the secret shells in SM (empty). Now populate them with real values.
Run once per environment. `put-secret-value` not `create-secret` — the shell already exists.

**DB secret:**
```bash
aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/postgres \
  --region ap-south-1 \
  --secret-string '{"DB_HOST":"postgres-svc","DB_PORT":"5432","DB_NAME":"pulseauth","DB_USER":"pulseadmin","DB_PASSWORD":"<your-strong-password>"}'
```

**Redis secret:**
```bash
aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/redis \
  --region ap-south-1 \
  --secret-string '{"REDIS_HOST":"redis-svc","REDIS_PORT":"6379","REDIS_PASSWORD":"<your-redis-password>"}'
```

**Mail secret:**
```bash
aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/mail \
  --region ap-south-1 \
  --secret-string '{"MAIL_HOST":"<smtp-host>","MAIL_PORT":"587","MAIL_USER":"<user>","MAIL_PASSWORD":"<password>","MAIL_SMTP_AUTH":"true","MAIL_SMTP_TLS":"true"}'
```

## Step 4: Apply manifests in order

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-storageclass.yaml
# 02-serviceaccount.yaml is handled by Helm — do NOT apply
kubectl apply -f 03-secretstore.yaml
kubectl apply -f 04-externalsecret-db.yaml
kubectl apply -f 05-externalsecret-redis.yaml
kubectl apply -f 06-externalsecret-mail.yaml
```

Wait for ExternalSecrets to sync (creates k8s Secrets):
```bash
kubectl get externalsecret -n pulseauth
# STATUS should be SecretSynced
```

Force re-sync if stuck:
```bash
kubectl annotate externalsecret pulseauth-db-external-secret \
  -n pulseauth force-sync=$(date +%s) --overwrite
```

```bash
kubectl apply -f 07-postgres-statefulset.yaml
kubectl apply -f 08-postgres-service.yaml
```

Wait for postgres to be Running before proceeding:
```bash
kubectl get pods -n pulseauth
```

```bash
kubectl apply -f 09-redis-deployment.yaml
kubectl apply -f 10-redis-service.yaml
kubectl apply -f 11-pulseauth-deployment.yaml
kubectl apply -f 12-pulseauth-service.yaml
```

---

## Cleanup (prevent_destroy sequence)

`terraform destroy` will halt — SM secrets have `prevent_destroy = true`. This is intentional.

```bash
# Step 1: delete K8s resources (removes NLB from AWS)
kubectl delete namespace pulseauth
kubectl delete namespace external-secrets

# Step 2: delete SM secrets manually
aws secretsmanager delete-secret --secret-id eks-secrets-dev/pulseauth/postgres \
  --region ap-south-1 --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id eks-secrets-dev/pulseauth/redis \
  --region ap-south-1 --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id eks-secrets-dev/pulseauth/mail \
  --region ap-south-1 --force-delete-without-recovery

# Step 3: remove from TF state
cd ../terraform
terraform state rm module.secrets_manager.aws_secretsmanager_secret.postgres
terraform state rm module.secrets_manager.aws_secretsmanager_secret.redis
terraform state rm module.secrets_manager.aws_secretsmanager_secret.mail

# Step 4: destroy succeeds now
terraform destroy

# Step 5: check EC2 → Volumes — delete any "available" EBS volumes (reclaimPolicy: Retain)
```
