#!/usr/bin/env bash
# ==============================================================================
# apply-all.sh — Deploy UMS Application Stack to EKS (PRIVATE Nodegroup)
# ==============================================================================
#
# USAGE:
#   1. Connect to the bastion host via AWS SSM Session Manager:
#        aws ssm start-session --target <bastion-instance-id> --region ap-south-1
#
#   2. Once inside the SSM session, run this script:
#        bash ~/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_ebs_csi_addon/eks-private-nodegroup/k8s-manifests/apply-all.sh
#
#   The manifests are located at:
#     ~/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_ebs_csi_addon/eks-private-nodegroup/k8s-manifests/
#
# PREREQUISITES:
#   - kubectl is configured (kubeconfig updated by bastion user_data)
#   - EKS cluster is running with EBS CSI addon installed
#   - SSM session is active
# ==============================================================================

set -euo pipefail

MANIFESTS_DIR="${HOME}/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_ebs_csi_addon/eks-private-nodegroup/k8s-manifests"

echo "============================================================"
echo "  Deploying UMS Application Stack (PRIVATE Nodegroup)"
echo "============================================================"
echo ""

echo "[1/10] Applying 00-namespace.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/00-namespace.yaml"
echo ""

echo "[2/10] Applying 01-storage-class.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/01-storage-class.yaml"
echo ""

echo "[3/10] Applying 02-postgres-pvc.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/02-postgres-pvc.yaml"
echo ""

echo "[4/10] Applying 03-postgres-secret.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/03-postgres-secret.yaml"
echo ""

echo "[5/10] Applying 04-postgres-configmap.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/04-postgres-configmap.yaml"
echo ""

echo "[6/10] Applying 05-postgres-deployment.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/05-postgres-deployment.yaml"
echo ""

echo "Waiting for PostgreSQL deployment to become ready ..."
kubectl rollout status deployment/postgres -n ums-app --timeout=300s
echo "PostgreSQL is ready."
echo ""

echo "[7/10] Applying 06-postgres-clusterip-svc.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/06-postgres-clusterip-svc.yaml"
echo ""

echo "[8/10] Applying 07-ums-configmap.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/07-ums-configmap.yaml"
echo ""

echo "[9/10] Applying 08-ums-deployment.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/08-ums-deployment.yaml"
echo ""

echo "[10/10] Applying 09-ums-loadbalancer-svc.yaml ..."
kubectl apply -f "${MANIFESTS_DIR}/09-ums-loadbalancer-svc.yaml"
echo ""

echo "============================================================"
echo "  All manifests applied. Final resource status:"
echo "============================================================"
kubectl get all -n ums-app
echo ""
echo "NOTE: The LoadBalancer external IP/hostname may take 1-3 minutes"
echo "      to be provisioned by AWS. Run the following to check:"
echo "  kubectl get svc ums-loadbalancer-svc -n ums-app -w"
