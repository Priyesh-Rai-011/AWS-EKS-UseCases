#!/usr/bin/env bash
# Eve — frontend-dev (namespace: frontend-prod only)
# Expected: read + logs in frontend-prod, everything else DENIED
set -euo pipefail

ROLE_ARN=${1:-"$(terraform -chdir=../terraform output -json iam_role_arns | jq -r '.frontend_dev')"}
CLUSTER=$(terraform -chdir=../terraform output -raw cluster_name)
REGION="ap-south-1"

echo "=== Assuming role: eks-frontend-dev-role (Eve) ==="
CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name eve \
  --region "$REGION" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

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

run_test "get pods (frontend-prod)"         ALLOWED get pods           -n frontend-prod
run_test "view logs (frontend-prod)"        ALLOWED get pods/log       -n frontend-prod
run_test "get deployments (frontend-prod)"  ALLOWED get deployments    -n frontend-prod
run_test "exec into pod (frontend-prod)"    DENIED  create pods/exec   -n frontend-prod
run_test "create deployment (frontend-prod)"DENIED  create deployments -n frontend-prod
run_test "patch deployment (frontend-prod)" DENIED  patch deployments  -n frontend-prod
run_test "get secrets (frontend-prod)"      DENIED  get secrets        -n frontend-prod
run_test "get pods (backend-prod)"          DENIED  get pods           -n backend-prod
run_test "view logs (backend-prod)"         DENIED  get pods/log       -n backend-prod
run_test "get nodes"                        DENIED  get nodes

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
