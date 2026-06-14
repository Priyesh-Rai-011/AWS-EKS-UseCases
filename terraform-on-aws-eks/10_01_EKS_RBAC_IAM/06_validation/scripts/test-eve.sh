#!/usr/bin/env bash
# Eve — frontend-dev (readonly in backend-prod)
# Angular runs on S3 — no frontend-prod k8s namespace.
# Eve can only VIEW backend pods/logs to check API health.
# Expected: read + logs in backend-prod, NO exec, NO secrets, NO write
set -euo pipefail

ROLE_ARN=${1:-"$(terraform -chdir=../terraform output -json persona_role_arns | jq -r '.frontend_dev')"}
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
