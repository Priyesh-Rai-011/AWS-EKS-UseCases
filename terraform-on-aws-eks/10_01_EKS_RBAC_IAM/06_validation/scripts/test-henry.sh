#!/usr/bin/env bash
# Henry — break-glass (system:masters via eks-cluster-admin-role)
# NEVER use this role for day-to-day work.
# Expected: everything ALLOWED — this is full cluster-admin
# system:masters group bypasses all RBAC — no manifest needed
set -euo pipefail

ROLE_ARN=${1:-"$(terraform -chdir=../terraform output -json persona_role_arns | jq -r '.cluster_admin')"}
CLUSTER=$(terraform -chdir=../terraform output -raw cluster_name)
REGION="ap-south-1"

echo "=== Assuming role: eks-cluster-admin-role (Henry — BREAK-GLASS) ==="
echo "WARNING: This role has system:masters access. Use only in emergencies."
CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name henry-breakglass \
  --region "$REGION" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

echo ""
echo "=== Henry access matrix (all ALLOWED — system:masters) ==="
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

run_test "get pods (backend-prod)"     ALLOWED get pods           -n backend-prod
run_test "get secrets (backend-prod)"  ALLOWED get secrets        -n backend-prod
run_test "exec into pod (backend-prod)"ALLOWED create pods/exec   -n backend-prod
run_test "delete pod (backend-prod)"   ALLOWED delete pods        -n backend-prod
run_test "get nodes (cluster-wide)"    ALLOWED get nodes
run_test "list namespaces"             ALLOWED list namespaces
run_test "create namespace"            ALLOWED create namespaces
run_test "delete namespace"            ALLOWED delete namespaces

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
echo ""
echo "REMINDER: Revoke/drop these credentials immediately after use."
