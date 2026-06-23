#!/usr/bin/env bash
# Henry — break-glass (AmazonEKSClusterAdminPolicy)
# NEVER use this role for day-to-day work.
# Expected: everything ALLOWED — full cluster-admin
set -euo pipefail

export AWS_PROFILE=henry
CLUSTER="eks-rbac-dev"
REGION="ap-south-1"

echo "=== Identity: $(aws sts get-caller-identity --query Arn --output text) ==="
echo "WARNING: This role has cluster-admin access. Use only in emergencies."
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --profile henry 2>/dev/null

echo ""
echo "=== Henry access matrix (all ALLOWED — cluster-admin) ==="
PASS=0; FAIL=0

run_test() {
  local label="$1"; local expected="$2"; shift 2
  local result
  if kubectl auth can-i "$@" 2>/dev/null | grep -q "^yes"; then
    result="ALLOWED"
  else
    result="DENIED"
  fi
  if [ "$result" = "$expected" ]; then
    echo "  PASS  [$result] $label"
    ((PASS++))
  else
    echo "  FAIL  [$result] $label (expected $expected)"
    ((FAIL++))
  fi
}

run_test "get pods (backend-prod)"      ALLOWED get pods           -n backend-prod
run_test "get secrets (backend-prod)"   ALLOWED get secrets        -n backend-prod
run_test "exec into pod (backend-prod)" ALLOWED create pods/exec   -n backend-prod
run_test "delete pod (backend-prod)"    ALLOWED delete pods        -n backend-prod
run_test "get nodes (cluster-wide)"     ALLOWED get nodes
run_test "list namespaces"              ALLOWED list namespaces
run_test "create namespace"             ALLOWED create namespaces
run_test "delete namespace"             ALLOWED delete namespaces

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
echo ""
echo "REMINDER: Revoke/drop these credentials immediately after use."
