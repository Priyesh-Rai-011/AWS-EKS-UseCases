#!/usr/bin/env bash
# Deploy UMS stack to EKS — IRSA PUBLIC nodegroup
#
# Prerequisites:
#   1. terraform apply completed and ums_app_role_arn output captured
#   2. Update 02-ums-serviceaccount.yaml annotation with the actual role ARN:
#      eks.amazonaws.com/role-arn: <ums_app_role_arn from terraform output>
#
#   3. Connect to bastion:
#      aws ssm start-session --target <bastion-instance-id> --region ap-south-1
#
#   4. Run this script from the bastion

set -euo pipefail

MANIFESTS_DIR="${HOME}/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_01_irsa_vs_podidentity/eks-public-nodegroup/k8s-manifests"

echo "==> Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --wait

echo "==> Deploying UMS stack (IRSA public nodegroup)"

kubectl apply -f "${MANIFESTS_DIR}/00-namespace.yaml"
kubectl apply -f "${MANIFESTS_DIR}/01-storageclass.yaml"
kubectl apply -f "${MANIFESTS_DIR}/02-ums-serviceaccount.yaml"
kubectl apply -f "${MANIFESTS_DIR}/03-postgres-secret-store.yaml"
kubectl apply -f "${MANIFESTS_DIR}/04-postgres-externalsecret.yaml"

echo "==> Waiting for ExternalSecret to sync postgres-secret from Secrets Manager..."
kubectl wait externalsecret/postgres-external-secret \
  -n ums-app \
  --for=condition=Ready \
  --timeout=120s

kubectl apply -f "${MANIFESTS_DIR}/05-postgres-configmap.yaml"
kubectl apply -f "${MANIFESTS_DIR}/06-postgres-statefulset.yaml"
kubectl apply -f "${MANIFESTS_DIR}/07-postgres-service.yaml"

echo "==> Waiting for postgres-0 to be ready..."
kubectl rollout status statefulset/postgres -n ums-app --timeout=300s

kubectl apply -f "${MANIFESTS_DIR}/08-ums-configmap.yaml"
kubectl apply -f "${MANIFESTS_DIR}/09-ums-deployment.yaml"
kubectl apply -f "${MANIFESTS_DIR}/10-ums-service.yaml"

echo "==> Waiting for ums-app deployment to be ready..."
kubectl rollout status deployment/ums-app -n ums-app --timeout=300s

echo ""
echo "==> Stack deployed. Resources:"
kubectl get all -n ums-app
echo ""
echo "==> ALB DNS (may take 1-3 min to provision):"
kubectl get svc ums-svc -n ums-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
