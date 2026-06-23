# Deployment Steps — 10_01 EKS RBAC + IAM

Full sequence from zero to working PulseAuth + validated RBAC personas.

---

## Prerequisites

- AWS CLI configured with admin profile (the one that owns the Terraform state)
- `kubectl` installed
- `helm` installed
- Docker Desktop running (for backend image build)
- Node.js + Angular CLI installed (for frontend build)

---

## 1. Terraform apply

```bash
cd terraform-on-aws-eks/10_01_EKS_RBAC_IAM/terraform
terraform init
terraform plan
terraform apply
```

Creates: VPC, EKS cluster, 2 node groups, bastion, ECR repo, S3 frontend bucket,
Secrets Manager shells (empty), IRSA role for ESO, 8 IAM personas + groups + access entries.

```bash
# Grab outputs
terraform output ssm_connect_command    # bastion SSM session
terraform output configure_kubectl      # update local kubeconfig
```

Run the kubectl output to configure local access with your admin credentials.

---

## 2. Add your admin access entry

Your IAM user (`priysh.rai@minfytech.com`) needs cluster-admin access separately —
Terraform doesn't create an access entry for the cluster creator.

```bash
aws eks create-access-entry \
  --cluster-name eks-rbac-dev \
  --principal-arn arn:aws:iam::183295435445:user/priysh.rai@minfytech.com \
  --region ap-south-1

aws eks associate-access-policy \
  --cluster-name eks-rbac-dev \
  --principal-arn arn:aws:iam::183295435445:user/priysh.rai@minfytech.com \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region ap-south-1
```

Verify:

```bash
kubectl get nodes
# NAME    STATUS   ROLES    AGE   VERSION
# ip-...  Ready    <none>   ...   v1.33.x
```

---

## 3. Install ESO (External Secrets Operator)

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

Wait for it:

```bash
kubectl get pods -n external-secrets -w
# external-secrets-... Running
```

---

## 4. Seed Secrets Manager

Terraform created empty shells. Seed real values now.

```bash
# Postgres credentials
aws secretsmanager put-secret-value \
  --secret-id eks-rbac-dev/pulseauth/postgres \
  --region ap-south-1 \
  --secret-string '{"POSTGRES_DB":"pulseauthdb","POSTGRES_USER":"pulseuser","POSTGRES_PASSWORD":"YourStrongPassword"}'

# Gmail SMTP credentials (use a Gmail App Password — not your account password)
aws secretsmanager put-secret-value \
  --secret-id eks-rbac-dev/pulseauth/mail \
  --region ap-south-1 \
  --secret-string '{"MAIL_HOST":"smtp.gmail.com","MAIL_USER":"your@gmail.com","MAIL_PASS":"your16charapppassword"}'
```

---

## 5. Apply namespaces

```bash
kubectl apply -f 03_rbac_manifests/k8s-manifests/00-namespaces.yaml
# namespace/backend-prod created
# namespace/frontend-prod created
# namespace/monitoring created
```

---

## 6. Apply RBAC manifests

```bash
kubectl apply -f 03_rbac_manifests/k8s-manifests/cluster-roles/
kubectl apply -f 03_rbac_manifests/k8s-manifests/roles/
kubectl apply -f 03_rbac_manifests/k8s-manifests/cluster-role-bindings/
kubectl apply -f 03_rbac_manifests/k8s-manifests/role-bindings/
```

Verify bindings landed:

```bash
kubectl get clusterroles | grep -E "devops|backend|readonly|security"
kubectl get rolebindings -n backend-prod
```

---

## 7. Apply StorageClass

```bash
kubectl apply -f 05_test_workloads/postgres/storageclass.yaml
```

---

## 8. Apply ServiceAccount + SecretStore + ExternalSecrets

```bash
kubectl apply -f 05_test_workloads/pulseauth/serviceaccount.yaml
kubectl apply -f 05_test_workloads/eso/secretstore.yaml

# Wait for SecretStore to become Ready
kubectl get secretstore -n backend-prod
# pulseauth-secret-store   Valid

kubectl apply -f 05_test_workloads/eso/externalsecret.yaml
kubectl apply -f 05_test_workloads/eso/externalsecret-mail.yaml
```

Wait for k8s Secrets to be created:

```bash
kubectl get externalsecret -n backend-prod
# NAME                                  READY   STATUS
# pulseauth-postgres-external-secret    True    SecretSynced
# pulseauth-mail-external-secret        True    SecretSynced

kubectl get secret -n backend-prod | grep pulseauth
# pulseauth-postgres-secret
# pulseauth-mail-secret
```

If status is not `SecretSynced` after 30 seconds, force sync:

```bash
kubectl annotate externalsecret pulseauth-postgres-external-secret \
  -n backend-prod force-sync=$(date +%s) --overwrite
```

---

## 9. Deploy Redis

```bash
kubectl apply -f 05_test_workloads/redis/deployment.yaml
kubectl apply -f 05_test_workloads/redis/service.yaml

kubectl get pods -n backend-prod -l app=redis
# redis-... Running
```

---

## 10. Deploy Postgres

```bash
kubectl apply -f 05_test_workloads/postgres/statefulset.yaml
kubectl apply -f 05_test_workloads/postgres/service.yaml
```

Wait for Postgres to be Ready before continuing — Spring Boot will crash if it can't connect:

```bash
kubectl get pods -n backend-prod -w
# postgres-0   0/1   Pending → ContainerCreating → Running
```

```bash
kubectl exec -n backend-prod postgres-0 -- pg_isready
# /var/run/postgresql:5432 - accepting connections
```

---

## 11. Build and push backend image

```bash
cd pulseauth/backend/pulseauth

# Authenticate to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  183295435445.dkr.ecr.ap-south-1.amazonaws.com

# Build
docker build -t pulseauth .

# Tag and push
docker tag pulseauth:latest 183295435445.dkr.ecr.ap-south-1.amazonaws.com/pulseauth:latest
docker push 183295435445.dkr.ecr.ap-south-1.amazonaws.com/pulseauth:latest
```

---

## 12. Deploy PulseAuth backend

```bash
cd ../../../  # back to 10_01_EKS_RBAC_IAM/

kubectl apply -f 05_test_workloads/pulseauth/serviceaccount.yaml
kubectl apply -f 05_test_workloads/pulseauth/deployment.yaml
kubectl apply -f 05_test_workloads/pulseauth/service.yaml
```

Watch it start:

```bash
kubectl get pods -n backend-prod -w
# pulseauth-...   0/1   Pending → Running
```

Check logs if it doesn't go Ready:

```bash
kubectl logs -n backend-prod -l app=pulseauth --tail=50
```

Get the NLB address:

```bash
kubectl get svc pulseauth-svc -n backend-prod
# EXTERNAL-IP   a490d91c6f7ce464c95cbe4f08789fd6-921409174.ap-south-1.elb.amazonaws.com
```

NLB takes 2-3 minutes to provision. Test once External-IP is set:

```bash
curl http://<NLB-ADDRESS>/api/users/health
# {"status":"UP"}
```

---

## 13. Build and deploy Angular frontend

```bash
cd pulseauth/pulseauth-ui

# Update NLB endpoint in api.service.ts if it changed
# src/app/api.service.ts line 4: const BASE = 'http://<NLB-ADDRESS>/api/users'

npm install
npm run build
# Output: dist/pulseauth-ui/browser/

aws s3 sync dist/pulseauth-ui/browser/ \
  s3://eks-rbac-dev-frontend \
  --delete \
  --region ap-south-1
```

Frontend URL:

```text
http://eks-rbac-dev-frontend.s3-website.ap-south-1.amazonaws.com
```

---

## 14. Configure AWS profiles for RBAC personas

Each persona needs an AWS CLI profile pointing to their access key + the role they assume.

```ini
# ~/.aws/credentials  — add access keys for each persona
[alice]
aws_access_key_id     = AKIA...
aws_secret_access_key = ...

# ~/.aws/config  — role assumption config
[profile alice]
role_arn       = arn:aws:iam::183295435445:role/eks-rbac-dev-devops-admin-role
source_profile = alice
```

Repeat for: bob, charlie, dave, eve, grace (their respective role ARNs).
Henry is a user policy — no `role_arn` needed, uses keys directly with cluster-admin-role.

Verify identity:

```bash
aws sts get-caller-identity --profile alice
# "Arn": "arn:aws:iam::183295435445:assumed-role/eks-rbac-dev-devops-admin-role/..."
```

---

## 15. Run validation scripts

From PowerShell (not bash — `aws` not in Git Bash PATH on Windows):

```powershell
cd 06_validation/scripts

.\test-alice.ps1
.\test-bob.ps1
.\test-charlie.ps1
.\test-dave.ps1
.\test-eve.ps1
.\test-grace.ps1
.\test-henry.ps1
```

Expected: all show `X passed, 0 failed`.

Each script sets `$env:AWS_PROFILE`, runs `aws eks update-kubeconfig`, then tests
`kubectl auth can-i` against the permission matrix for that persona.

---

## Cleanup

```bash
# Delete k8s workloads (NLB and PVC survive terraform destroy — must delete first)
kubectl delete svc pulseauth-svc -n backend-prod    # destroys NLB
kubectl delete pvc --all -n backend-prod            # releases EBS claim

# Wait for NLB to terminate (check EC2 → Load Balancers)
# Then destroy infra
cd terraform
terraform destroy
```

**Manual cleanup required after `terraform destroy`:**

- EBS volumes with `reclaimPolicy: Retain` persist. Delete from EC2 → Volumes.
- S3 buckets (Terraform won't delete non-empty buckets):
  ```bash
  aws s3 rm s3://eks-rbac-dev-frontend --recursive --region ap-south-1
  terraform destroy  # run again
  ```

---

## Cost estimate

| Resource | $/hr |
| -------- | ---- |
| EKS cluster | $0.10 |
| 2x t3.medium nodes | $0.084 |
| NAT Gateway | $0.045 + data |
| NLB | $0.008 + LCU |
| **Total** | **~$0.24/hr (~$5.70/day)** |

Always `terraform destroy` when done.
