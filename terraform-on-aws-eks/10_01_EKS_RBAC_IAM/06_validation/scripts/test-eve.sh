#!/usr/bin/env bash
# Eve — frontend-dev (readonly in backend-prod)
# Angular runs on S3 — no frontend-prod k8s workloads.
# Eve can only VIEW backend pods/logs to check API health.
# Expected: read + logs in backend-prod, NO exec, NO secrets, NO write
set -euo pipefail

export AWS_PROFILE=eve
CLUSTER="eks-rbac-dev"
REGION="ap-south-1"

echo "=== Identity: $(aws sts get-caller-identity --query Arn --output text) ==="
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --profile eve 2>/dev/null

echo ""
echo "=== Eve access matrix ==="
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

run_test "get pods (backend-prod)"          ALLOWED get pods           -n backend-prod
run_test "view logs (backend-prod)"         ALLOWED get pods/log       -n backend-prod
run_test "get deployments (backend-prod)"   ALLOWED get deployments    -n backend-prod
run_test "exec into pod (backend-prod)"     DENIED  create pods/exec   -n backend-prod
run_test "create deployment (backend-prod)" DENIED  create deployments -n backend-prod
run_test "patch deployment (backend-prod)"  DENIED  patch deployments  -n backend-prod
run_test "get secrets (backend-prod)"       DENIED  get secrets        -n backend-prod
run_test "get nodes (cluster-wide)"         DENIED  get nodes
run_test "list namespaces"                  DENIED  list namespaces

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
