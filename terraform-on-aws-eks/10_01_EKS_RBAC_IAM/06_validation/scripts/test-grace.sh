#!/usr/bin/env bash
# Grace — security-auditor (cluster-wide)
# Expected: see RBAC bindings, list secrets, view logs, exec NO
set -euo pipefail

export AWS_PROFILE=grace
CLUSTER="eks-rbac-dev"
REGION="ap-south-1"

echo "=== Identity: $(aws sts get-caller-identity --query Arn --output text) ==="
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --profile grace 2>/dev/null

echo ""
echo "=== Grace access matrix ==="
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

run_test "get clusterrolebindings"          ALLOWED get clusterrolebindings
run_test "get rolebindings (backend-prod)"  ALLOWED get rolebindings    -n backend-prod
run_test "get serviceaccounts (all ns)"     ALLOWED get serviceaccounts -n backend-prod
run_test "get secrets (backend-prod)"       ALLOWED get secrets         -n backend-prod
run_test "get secrets (frontend-prod)"      ALLOWED get secrets         -n frontend-prod
run_test "view logs (backend-prod)"         ALLOWED get pods/log        -n backend-prod
run_test "get networkpolicies"              ALLOWED get networkpolicies -n backend-prod
run_test "exec into pod"                    DENIED  create pods/exec    -n backend-prod
run_test "delete pod"                       DENIED  delete pods         -n backend-prod
run_test "create deployment"                DENIED  create deployments  -n backend-prod

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
