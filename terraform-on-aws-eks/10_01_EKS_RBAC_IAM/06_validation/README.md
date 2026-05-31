# 06 — Validation

## Problem
"I think RBAC is working" is not good enough. How do we prove permissions are exactly what we intended — before a developer hits a wall in production?

## Concepts
`kubectl auth can-i` — tests permissions for current user or any subject:
```bash
# Am I allowed?
kubectl auth can-i get pods -n dev

# Can a specific group do this?
kubectl auth can-i get secrets -n dev --as-group eks-developers --as fake-user

# List all permissions for current user
kubectl auth can-i --list -n dev
```

Expected results for eks-developers group in dev namespace:
```
get pods              → yes
list deployments      → yes
get pods/log          → yes
get secrets           → no
create pods/exec      → no
delete deployments    → no
get pods -n prod      → no
```

## Implementation
scripts/:
- test-admin-access.sh
- test-readonly-access.sh
- test-developer-access.sh

screenshots/:
- Save terminal output proving each role's access

## Revision Notes
- Run validation after EVERY RBAC change — not just at the end.
- `kubectl auth can-i` tests RBAC only. It does not test IAM mapping.
- If mapping is broken, you get auth failure before RBAC is even checked.
