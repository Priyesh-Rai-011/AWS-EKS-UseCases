#!/usr/bin/env bash
# Deploy UMS stack to EKS — PRIVATE nodegroup
#
# Run from bastion via SSM:
#   aws ssm start-session --target <bastion-instance-id> --region ap-south-1
#   bash ~/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_ebs_csi_addon/eks-private-nodegroup/k8s-manifests/apply-all.sh

set -euo pipefail

MANIFESTS_DIR="${HOME}/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_ebs_csi_addon/eks-private-nodegroup/k8s-manifests"

echo "==> Deploying UMS stack (private nodegroup)"

kubectl apply -f "${MANIFESTS_DIR}/00-namespace.yaml"
kubectl apply -f "${MANIFESTS_DIR}/01-storageclass.yaml"
kubectl apply -f "${MANIFESTS_DIR}/02-postgres-secret.yaml"
kubectl apply -f "${MANIFESTS_DIR}/03-postgres-configmap.yaml"
kubectl apply -f "${MANIFESTS_DIR}/04-postgres-statefulset.yaml"
kubectl apply -f "${MANIFESTS_DIR}/05-postgres-service.yaml"

echo "==> Waiting for postgres-0 to be ready..."
kubectl rollout status statefulset/postgres -n ums-app --timeout=300s

kubectl apply -f "${MANIFESTS_DIR}/06-ums-configmap.yaml"
kubectl apply -f "${MANIFESTS_DIR}/07-ums-deployment.yaml"
kubectl apply -f "${MANIFESTS_DIR}/08-ums-service.yaml"

echo "==> Waiting for ums-app deployment to be ready..."
kubectl rollout status deployment/ums-app -n ums-app --timeout=300s

echo ""
echo "==> Stack deployed. Resources:"
kubectl get all -n ums-app
echo ""
echo "==> ALB DNS (may take 1-3 min to provision):"
kubectl get svc ums-svc -n ums-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
