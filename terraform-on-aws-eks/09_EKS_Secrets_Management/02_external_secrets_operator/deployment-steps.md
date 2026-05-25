# Deployment Steps — ESO + IRSA

## Prerequisites

- Terraform CLI installed
- `aws` CLI configured for `ap-south-1`
- `helm` installed
- `docker` running (for image build + push)
- Bastion EC2 accessible via SSM (all kubectl commands run on bastion)

---

## 1 — Provision infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This creates: VPC, EKS cluster, bastion, ECR repo, ESO IAM role (IRSA), and the three SM secret shells.

**Secret shells are created by Terraform — but contain no values yet.**
`eks-secrets-dev/pulseauth/postgres`, `redis`, and `mail` exist in Secrets Manager with empty content. You seed them in Step 3.

Capture outputs:

```bash
terraform output configure_kubectl
terraform output ecr_repository_url
terraform output eso_role_arn
```

---

## 2 — Configure kubectl

Connect to bastion via SSM, then:

```bash
aws eks update-kubeconfig --region ap-south-1 --name eks-dev
kubectl get nodes
# Expected: 2x t3.medium   Ready
```

---

## 3 — Seed secrets in AWS Secrets Manager

Terraform created the secret shells. Now populate them with real values.
Run this once per environment. Never put real values in Terraform.

```bash
aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/postgres \
  --region ap-south-1 \
  --secret-string '{"DB_HOST":"postgres-svc","DB_PORT":"5432","DB_NAME":"pulseauth","DB_USER":"pulseadmin","DB_PASSWORD":"YourStrongPass"}'

aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/redis \
  --region ap-south-1 \
  --secret-string '{"REDIS_HOST":"redis-svc","REDIS_PORT":"6379","REDIS_PASSWORD":"YourRedisPass"}'

aws secretsmanager put-secret-value \
  --secret-id eks-secrets-dev/pulseauth/mail \
  --region ap-south-1 \
  --secret-string '{"MAIL_HOST":"smtp.gmail.com","MAIL_PORT":"587","MAIL_USER":"you@gmail.com","MAIL_PASSWORD":"app-password","MAIL_SMTP_AUTH":"true","MAIL_SMTP_TLS":"true"}'
```

Note: `put-secret-value` (not `create-secret`) because the shell already exists from `terraform apply`.

---

## 4 — Install EBS CSI driver

Terraform does not include EBS CSI. Postgres PVCs hang Pending without it.

You need an IAM role for EBS CSI — copy from `07_EKS_EBS_CSI` or create one with `AmazonEBSCSIDriverPolicy` using Pod Identity.

```bash
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<EBS_CSI_ROLE_ARN>
```

---

## 5 — Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace --wait
```

---

## 6 — Annotate ESO service account with IRSA role

```bash
ESO_ROLE=$(cd terraform && terraform output -raw eso_role_arn)

kubectl annotate serviceaccount external-secrets \
  -n external-secrets \
  eks.amazonaws.com/role-arn=$ESO_ROLE \
  --overwrite
```

---

## 7 — Build and push PulseAuth image

```bash
ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $ECR_URL

docker build -t pulseauth ../../../pulseauth/app/pulseauth/
docker tag pulseauth:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

---

## 8 — Apply manifests in order

```bash
kubectl apply -f k8s-manifests/00-namespace.yaml
kubectl apply -f k8s-manifests/01-storageclass.yaml
kubectl apply -f k8s-manifests/03-secretstore.yaml
kubectl apply -f k8s-manifests/04-externalsecret-db.yaml
kubectl apply -f k8s-manifests/05-externalsecret-redis.yaml
kubectl apply -f k8s-manifests/06-externalsecret-mail.yaml
```

Wait for ESO to sync before deploying workloads:

```bash
kubectl get externalsecret -n pulseauth -w
# All three must show STATUS: SecretSynced before continuing
```

If stuck — check [`troubleshooting.md`](troubleshooting.md).

Then deploy workloads:

```bash
kubectl apply -f k8s-manifests/07-postgres-statefulset.yaml
kubectl apply -f k8s-manifests/08-postgres-service.yaml

# EBS volume provisions here — wait for PVC to bind (~30s)
kubectl get pvc -n pulseauth -w
# postgres-data-postgres-0: Pending → Bound

# Wait for postgres to be ready before deploying app
kubectl get pods -n pulseauth -w
# postgres-0: Running 1/1

kubectl apply -f k8s-manifests/09-redis-deployment.yaml
kubectl apply -f k8s-manifests/10-redis-service.yaml
kubectl apply -f k8s-manifests/11-pulseauth-deployment.yaml
kubectl apply -f k8s-manifests/12-pulseauth-service.yaml
```

---

## 9 — Verify

```bash
kubectl get pods,svc,secret,externalsecret -n pulseauth

# NLB takes ~2 min to provision
kubectl get svc pulseauth-svc -n pulseauth
# EXTERNAL-IP appears when ready

curl http://<EXTERNAL-IP>/api/users/health
# Expected: {"status":"UP"}
```

---

## Cleanup

`prevent_destroy = true` is set on all SM secrets. `terraform destroy` will halt until you remove them manually first.

```bash
# Step 1: delete K8s resources — lets AWS clean up the NLB
kubectl delete namespace pulseauth
kubectl delete namespace external-secrets
# Wait ~2 min for NLB to deregister targets

# Step 2: delete SM secrets manually
# (terraform destroy halts without this — that's intentional, prevent_destroy)
aws secretsmanager delete-secret \
  --secret-id eks-secrets-dev/pulseauth/postgres \
  --region ap-south-1 --force-delete-without-recovery

aws secretsmanager delete-secret \
  --secret-id eks-secrets-dev/pulseauth/redis \
  --region ap-south-1 --force-delete-without-recovery

aws secretsmanager delete-secret \
  --secret-id eks-secrets-dev/pulseauth/mail \
  --region ap-south-1 --force-delete-without-recovery

# Step 3: remove from TF state (resources are gone, TF doesn't need to track them)
cd terraform
terraform state rm module.secrets_manager.aws_secretsmanager_secret.postgres
terraform state rm module.secrets_manager.aws_secretsmanager_secret.redis
terraform state rm module.secrets_manager.aws_secretsmanager_secret.mail

# Step 4: destroy succeeds now
terraform destroy

# Step 5: check EC2 → Volumes in AWS console
# Delete any "available" EBS volumes tagged Environment=dev (reclaimPolicy: Retain)
```

Running cost: EKS $0.10/hr + 2x t3.medium $0.083/hr + NAT GW $0.045/hr ≈ **$0.32/hr → ~$2.50 per 8hr session**.
