# Install Order — 03_csi_driver_ascp

## Step 1: Terraform apply

```bash
cd terraform/
terraform init
terraform apply
```

Note the ASCP role ARN from output:
```bash
terraform output ascp_role_arn
```

## Step 2: Install Secrets Store CSI Driver via Helm

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update

helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true
```

Wait for CSI driver pods to be Running:
```bash
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
```

## Step 3: Install AWS Secrets Store CSI Provider (ASCP) via Helm

```bash
helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
helm repo update

helm install secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  -n kube-system
```

Wait for provider pods to be Running:
```bash
kubectl get pods -n kube-system -l app=secrets-store-csi-driver-provider-aws
```

## Step 4: Seed the consolidated secret in AWS Secrets Manager

`terraform apply` already created the secret shell in SM (empty). Now populate it with real values.
Run once per environment. `put-secret-value` not `create-secret` — the shell already exists.

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
    "MAIL_USER":      "<mail-user>",
    "MAIL_PASSWORD":  "<mail-password>",
    "MAIL_SMTP_AUTH": "true",
    "MAIL_SMTP_TLS":  "true"
  }'
```

## Step 5: Apply manifests in order

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-storageclass.yaml
kubectl apply -f 02-serviceaccount.yaml
kubectl apply -f 03-secretproviderclass.yaml
```

Wait for Postgres before deploying the app (CSI driver creates the k8s Secret
`pulseauth-secrets` only when a pod with the CSI volume is scheduled):

```bash
kubectl apply -f 04-postgres-statefulset.yaml
kubectl apply -f 05-postgres-service.yaml
```

Wait for postgres-0 to be Running:
```bash
kubectl get pods -n pulseauth
```

```bash
kubectl apply -f 06-redis-deployment.yaml
kubectl apply -f 07-redis-service.yaml
kubectl apply -f 08-pulseauth-deployment.yaml
kubectl apply -f 09-pulseauth-service.yaml
```

---

## Cleanup (prevent_destroy sequence)

`terraform destroy` will halt — SM secret has `prevent_destroy = true`. This is intentional.

```bash
# Step 1: delete K8s resources (removes NLB from AWS)
kubectl delete namespace pulseauth

# Step 2: delete SM secret manually
aws secretsmanager delete-secret --secret-id eks-secrets-dev/pulseauth/all \
  --region ap-south-1 --force-delete-without-recovery

# Step 3: remove from TF state
cd ../terraform
terraform state rm module.secrets_manager.aws_secretsmanager_secret.pulseauth_all

# Step 4: destroy succeeds now
terraform destroy

# Step 5: check EC2 → Volumes — delete any "available" EBS volumes (reclaimPolicy: Retain)
```
