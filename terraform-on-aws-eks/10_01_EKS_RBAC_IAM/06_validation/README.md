# 04 — Validation

Prove the RBAC is actually doing what you configured.

---

## Prerequisites

1. `terraform apply` done (IAM roles + access entries exist)
2. `kubectl apply -f 03_rbac_manifests/k8s-manifests/` done (RBAC objects in cluster)
3. Running from bastion (or machine with AWS credentials + kubectl)

---

## Run all tests

```bash
cd terraform-on-aws-eks/10_01_EKS_RBAC_IAM/04_validation/scripts

chmod +x *.sh

bash test-alice.sh    # devops-admin
bash test-bob.sh      # devops-viewer (Frank uses same role)
bash test-charlie.sh  # backend-admin
bash test-dave.sh     # backend-dev
bash test-eve.sh      # frontend-dev
bash test-grace.sh    # security-auditor
```

---

## Expected output per persona

```
Alice   — 9 PASS, 1 FAIL expected: 0 FAIL
          (cluster-wide, exec yes, secrets denied)

Bob     — 10 PASS, 0 FAIL expected
          (cluster-wide read, exec denied, rollout yes, secrets denied)

Charlie — 10 PASS, 0 FAIL expected
          (backend-prod full, frontend-prod denied, nodes denied)

Dave    — 10 PASS, 0 FAIL expected
          (backend-prod read+rollout, exec denied, frontend denied)

Eve     — 10 PASS, 0 FAIL expected
          (frontend-prod read+logs, exec denied, backend denied)

Grace   — 10 PASS, 0 FAIL expected
          (cluster-wide audit, secrets list, exec denied, delete denied)
```

---

## What each test does

Each script:
1. Assumes the role via `aws sts assume-role`
2. Exports the 3 temp credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`)
3. Updates kubeconfig for the assumed role
4. Runs `kubectl auth can-i` for 10 operations
5. Checks ALLOWED vs DENIED against expected result
6. Prints PASS/FAIL per check + final count

---

## Manual verification

```bash
# Check what a specific group can do
kubectl auth can-i --list --as=fake-user --as-group=eks-devops -n backend-prod

# Verify bindings in place
kubectl get clusterrolebinding devops-admin-crb -o yaml
kubectl get rolebinding backend-dev-rb -n backend-prod -o yaml

# Verify access entries (AWS side)
aws eks list-access-entries \
  --cluster-name <cluster-name> \
  --region ap-south-1
```

---

## Revision notes

- `kubectl auth can-i` checks RBAC without actually running the command — safe to use.
- `--as=<user> --as-group=<group>` lets cluster-admin impersonate any identity for testing.
- Scripts use `--role-session-name alice/bob/etc` — appears in CloudTrail even when same role is shared (Bob + Frank both use eks-devops-role).
- If a test fails unexpectedly: check group name matches between access_entries.tf and the binding YAML.
