#!/usr/bin/env bash
# Alice — devops-admin
# Expected: cluster-wide access, exec YES, secrets NO
set -euo pipefail

ROLE_ARN=${1:-"$(terraform -chdir=../terraform output -json persona_role_arns | jq -r '.devops_admin')"}
CLUSTER=$(terraform -chdir=../terraform output -raw cluster_name)
REGION="ap-south-1"

echo "=== Assuming role: eks-devops-admin-role (Alice) ==="
CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name alice \
  --region "$REGION" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

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

run_test "get pods (backend-prod)"        ALLOWED get pods          -n backend-prod
run_test "get pods (frontend-prod)"       ALLOWED get pods          -n frontend-prod
run_test "get pods (kube-system)"         ALLOWED get pods          -n kube-system
run_test "exec into pod (backend-prod)"   ALLOWED create pods/exec  -n backend-prod
run_test "view logs (backend-prod)"       ALLOWED get pods/log      -n backend-prod
run_test "create deployment (backend)"    ALLOWED create deployments -n backend-prod
run_test "delete pod (frontend-prod)"     ALLOWED delete pods       -n frontend-prod
run_test "get secrets (backend-prod)"     DENIED  get secrets       -n backend-prod
run_test "get secrets (frontend-prod)"    DENIED  get secrets       -n frontend-prod
run_test "get nodes"                      ALLOWED get nodes

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
