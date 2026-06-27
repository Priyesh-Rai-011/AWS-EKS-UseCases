# Destroy Runbook — 10_01 EKS RBAC + IAM

`terraform destroy` alone will NOT clean everything. Several resources survive it.
Follow this sequence exactly or you'll have orphaned AWS resources still billing.

---

## Why order matters

| Resource | Problem |
|---|---|
| NLB (from LoadBalancer Service) | Created by k8s, unknown to Terraform. `terraform destroy` deletes the VPC but NLB blocks VPC deletion → destroy fails |
| EBS volumes (PVC reclaimPolicy: Retain) | Survive PVC deletion by design. Terraform never knew about them |
| S3 bucket (non-empty) | Terraform refuses to delete non-empty buckets → destroy fails |
| ECR repo (has images) | Terraform refuses to delete repos with images → destroy fails |
| Secrets Manager secrets (prevent_destroy = true) | Terraform halts on these → destroy fails halfway |
| IAM access keys (persona users) | Not created by Terraform, not deleted by it. Orphaned active keys = security risk |

---

## Step 1 — Delete k8s workloads (removes NLB + releases EBS)

```bash
# Delete LoadBalancer service — this triggers AWS to delete the NLB
kubectl delete svc pulseauth-svc -n backend-prod

# Wait for NLB to fully terminate before continuing
# Check: AWS Console → EC2 → Load Balancers → should disappear (~2 min)
aws elbv2 describe-load-balancers --region ap-south-1 \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,State:State.Code}' \
  --output table

# Delete PVC — releases the EBS volume claim
# (volume itself survives due to reclaimPolicy: Retain — handled in step 5)
kubectl delete pvc --all -n backend-prod

# Verify NLB gone before proceeding
# If still present after 5 min: check EC2 → Load Balancers and delete manually
```

---

## Step 2 — Delete IAM access keys (security — do this before anything else leaks)

These were created via CLI (`aws iam create-access-key`), not Terraform. Not deleted by destroy.

```bash
# List and delete access keys for each persona
for user in alice bob charlie dave eve grace henry; do
  echo "=== $user ==="
  keys=$(aws iam list-access-keys --user-name $user \
    --query 'AccessKeyMetadata[*].AccessKeyId' --output text 2>/dev/null)
  for key in $keys; do
    aws iam delete-access-key --user-name $user --access-key-id $key
    echo "  deleted $key"
  done
done
```

---

## Step 3 — Empty S3 bucket (frontend)

Terraform refuses to delete non-empty buckets.

```bash
aws s3 rm s3://eks-rbac-dev-frontend --recursive --region ap-south-1
# Confirm empty:
aws s3 ls s3://eks-rbac-dev-frontend --region ap-south-1
# (should return nothing)
```

---

## Step 4 — Empty ECR repo (delete all images)

Terraform refuses to delete ECR repos that contain images.

```bash
# List all images
aws ecr list-images \
  --repository-name pulseauth \
  --region ap-south-1 \
  --query 'imageIds[*]' \
  --output json

# Delete all images
aws ecr batch-delete-image \
  --repository-name pulseauth \
  --region ap-south-1 \
  --image-ids "$(aws ecr list-images \
    --repository-name pulseauth \
    --region ap-south-1 \
    --query 'imageIds[*]' \
    --output json)"
```

---

## Step 5 — Remove Secrets Manager secrets from Terraform state + delete them

Secrets have `prevent_destroy = true` — `terraform destroy` halts here.
Must remove from state first, then delete via CLI.

```bash
cd terraform-on-aws-eks/10_01_EKS_RBAC_IAM/terraform

# Remove all three secrets from Terraform state
terraform state rm module.secrets_manager.aws_secretsmanager_secret.postgres
terraform state rm module.secrets_manager.aws_secretsmanager_secret.redis
terraform state rm module.secrets_manager.aws_secretsmanager_secret.mail
terraform state rm module.secrets_manager.aws_secretsmanager_secret_version.postgres
terraform state rm module.secrets_manager.aws_secretsmanager_secret_version.redis
terraform state rm module.secrets_manager.aws_secretsmanager_secret_version.mail

# Now delete the actual secrets (force = skip 7-day recovery window)
aws secretsmanager delete-secret \
  --secret-id eks-rbac-dev/pulseauth/postgres \
  --force-delete-without-recovery \
  --region ap-south-1

aws secretsmanager delete-secret \
  --secret-id eks-rbac-dev/pulseauth/redis \
  --force-delete-without-recovery \
  --region ap-south-1

aws secretsmanager delete-secret \
  --secret-id eks-rbac-dev/pulseauth/mail \
  --force-delete-without-recovery \
  --region ap-south-1
```

---

## Step 6 — terraform destroy

Everything blocking destroy is now gone. Run it.

```bash
cd terraform-on-aws-eks/10_01_EKS_RBAC_IAM/terraform
terraform destroy
```

Review the plan. Type `yes`.

Expected destroy order (Terraform handles this automatically):
```
EKS access entries → EKS addons → node group → EKS cluster
IAM roles + policies (personas, ESO, EBS CSI)
IAM users + groups
ECR repo (now empty)
S3 bucket (now empty)
VPC + subnets + NAT GW + IGW
Bastion EC2 + security group
```

Takes 15-20 minutes. NAT GW and EKS cluster are the slowest.

---

## Step 7 — Delete orphaned EBS volumes (manual)

PVCs had `reclaimPolicy: Retain` — EBS volumes survive even after PVC deletion.
Terraform never created them (EBS CSI driver did), so terraform destroy doesn't touch them.

```bash
# Find available (unattached) volumes — these are the orphans
aws ec2 describe-volumes \
  --region ap-south-1 \
  --filters Name=status,Values=available \
  --query 'Volumes[*].{ID:VolumeId,Size:Size,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

Delete each one shown:

```bash
aws ec2 delete-volume --volume-id vol-xxxxxxxxxxxxxxxxx --region ap-south-1
```

---

## Step 8 — Verify nothing is billing

```bash
# No running EC2 instances
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType}' \
  --output table

# No NAT Gateways
aws ec2 describe-nat-gateways \
  --region ap-south-1 \
  --filter Name=state,Values=available \
  --query 'NatGateways[*].{ID:NatGatewayId,State:State}' \
  --output table

# No load balancers
aws elbv2 describe-load-balancers \
  --region ap-south-1 \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,State:State.Code}' \
  --output table

# No EBS volumes
aws ec2 describe-volumes \
  --region ap-south-1 \
  --filters Name=status,Values=available \
  --query 'Volumes[*].VolumeId' \
  --output table
```

All four should return empty. If not — something is still billing.

---

## Cost reminder

| Resource | Cost if forgotten |
|---|---|
| NAT Gateway | $0.045/hr = $32/month |
| EKS cluster | $0.10/hr = $72/month |
| t3.medium node (x2) | $0.084/hr = $60/month |
| NLB | $0.008/hr + LCU |
| EBS gp3 5Gi | ~$0.40/month |

**Total if left running: ~$165/month.**
