#!/usr/bin/env bash
# Grace — security-auditor (cluster-wide)
# Expected: see RBAC bindings, list secrets, view logs, exec NO
set -euo pipefail

ROLE_ARN=${1:-"$(terraform -chdir=../terraform output -json persona_role_arns | jq -r '.security')"}
CLUSTER=$(terraform -chdir=../terraform output -raw cluster_name)
REGION="ap-south-1"

echo "=== Assuming role: eks-security-role (Grace) ==="
CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name grace \
  --region "$REGION" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

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
