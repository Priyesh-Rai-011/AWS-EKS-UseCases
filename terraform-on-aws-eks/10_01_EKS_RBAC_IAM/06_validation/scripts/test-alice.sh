#!/usr/bin/env bash
# Alice — devops-admin
# Expected: cluster-wide access, exec YES, secrets NO
set -euo pipefail

export AWS_PROFILE=alice
CLUSTER="eks-rbac-dev"
REGION="ap-south-1"

echo "=== Identity: $(aws sts get-caller-identity --query Arn --output text) ==="
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --profile alice 2>/dev/null

echo ""
echo "=== Alice access matrix ==="
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

run_test "get pods (backend-prod)"        ALLOWED get pods           -n backend-prod
run_test "get pods (frontend-prod)"       ALLOWED get pods           -n frontend-prod
run_test "get pods (kube-system)"         ALLOWED get pods           -n kube-system
run_test "exec into pod (backend-prod)"   ALLOWED create pods/exec   -n backend-prod
run_test "view logs (backend-prod)"       ALLOWED get pods/log       -n backend-prod
run_test "create deployment (backend)"    ALLOWED create deployments -n backend-prod
run_test "delete pod (frontend-prod)"     ALLOWED delete pods        -n frontend-prod
run_test "get secrets (backend-prod)"     DENIED  get secrets        -n backend-prod
run_test "get secrets (frontend-prod)"    DENIED  get secrets        -n frontend-prod
run_test "get nodes"                      ALLOWED get nodes

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
