# 05 — Test Workloads

PulseAuth stack deployed into `backend-prod` namespace.
Real app, real secrets via ESO, real EBS-backed Postgres.
This is what validation scripts (06_validation) run against.

---

## Stack

```
AWS Secrets Manager
  eks-public-dev/pulseauth/postgres
    │
    │  ESO polls every 1h (IRSA via pulseauth-sa)
    ▼
ExternalSecret → k8s Secret: pulseauth-postgres-secret
    │
    ├──► Postgres StatefulSet (EBS gp3, subPath: pgdata)
    └──► PulseAuth Deployment (Spring Boot :8080)
              │
              ▼
         LoadBalancer Service → NLB → public endpoint
```

---

## Before applying

Two placeholders need real values from `terraform output`:

```bash
cd ../terraform
terraform output -raw eso_irsa_role_arn
terraform output -raw ecr_repository_url
```

Update:
- `pulseauth/serviceaccount.yaml` → `eks.amazonaws.com/role-arn`
- `pulseauth/deployment.yaml` → `image:`

Seed secrets in SM:
```bash
aws secretsmanager put-secret-value \
  --secret-id eks-public-dev/pulseauth/postgres \
  --region ap-south-1 \
  --secret-string '{"POSTGRES_DB":"pulseauthdb","POSTGRES_USER":"pulseuser","POSTGRES_PASSWORD":"YourStrongPass123"}'
```

Push PulseAuth image to ECR:
```bash
cd ../pulseauth/app/pulseauth
mvn clean package -DskipTests
docker build -t pulseauth:latest .
docker tag pulseauth:latest $(terraform -chdir=../terraform output -raw ecr_repository_url):latest
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $(terraform -chdir=../terraform output -raw ecr_repository_url)
docker push $(terraform -chdir=../terraform output -raw ecr_repository_url):latest
```

---

## Apply order

```bash
# 1. StorageClass (cluster-scoped, no namespace)
kubectl apply -f postgres/storageclass.yaml

# 2. ServiceAccount (IRSA annotation must exist before ESO runs)
kubectl apply -f pulseauth/serviceaccount.yaml

# 3. ESO resources (SecretStore + ExternalSecret)
kubectl apply -f eso/

# 4. Wait for secret to sync
kubectl get externalsecret -n backend-prod
kubectl get secret pulseauth-postgres-secret -n backend-prod

# 5. Postgres (needs secret to exist first)
kubectl apply -f postgres/statefulset.yaml
kubectl apply -f postgres/service.yaml

# 6. Wait for postgres ready
kubectl get pods -n backend-prod -w

# 7. PulseAuth
kubectl apply -f pulseauth/deployment.yaml
kubectl apply -f pulseauth/service.yaml

# 8. Get NLB endpoint
kubectl get svc pulseauth-svc -n backend-prod
```

---

## Verify

```bash
# All pods running
kubectl get pods,svc,pvc,secret,secretstore,externalsecret -n backend-prod

# App logs (Dave can run this, exec is denied)
kubectl logs deployment/pulseauth -n backend-prod --tail=50

# Health check via NLB
curl http://<NLB-ENDPOINT>/api/users/health
```
