#!/usr/bin/env bash
# Bob — devops-viewer (Frank uses same role)
# Expected: cluster-wide read, logs YES, exec NO, rollout YES, secrets NO
set -euo pipefail

export AWS_PROFILE=bob
CLUSTER="eks-rbac-dev"
REGION="ap-south-1"

echo "=== Identity: $(aws sts get-caller-identity --query Arn --output text) ==="
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --profile bob 2>/dev/null

echo ""
echo "=== Bob access matrix ==="
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
run_test "view logs (backend-prod)"       ALLOWED get pods/log       -n backend-prod
run_test "view logs (frontend-prod)"      ALLOWED get pods/log       -n frontend-prod
run_test "rollout (patch deployment)"     ALLOWED patch deployments  -n backend-prod
run_test "exec into pod"                  DENIED  create pods/exec   -n backend-prod
run_test "create deployment"              DENIED  create deployments -n backend-prod
run_test "delete pod"                     DENIED  delete pods        -n backend-prod
run_test "get secrets (backend-prod)"     DENIED  get secrets        -n backend-prod
run_test "get nodes"                      ALLOWED get nodes

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
