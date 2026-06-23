# 03 — RBAC Manifests

Code lives in: `k8s-manifests/`

---

## What gets created

```
ClusterRoles (4 — cluster-wide):
  devops-admin-cluster-role    → Alice: exec yes, create/delete yes, secrets no
  devops-viewer-cluster-role   → Bob+Frank: logs yes, exec no, rollout yes, secrets no
  readonly-cluster-role        → auditors: list/get only, no logs, no exec, no secrets
  security-audit-cluster-role  → Grace: secrets list yes, RBAC audit yes, exec no

Roles (3 — namespace-scoped):
  backend-admin-role (ns: backend-prod)  → Charlie: exec yes, full CRUD, secrets no
  backend-dev-role   (ns: backend-prod)  → Dave: logs yes, exec no, rollout yes
  frontend-dev-role  (ns: frontend-prod) → Eve: read + logs only

ClusterRoleBindings (4):
  devops-admin-crb    → Group: eks-devops-admins
  devops-viewer-crb   → Group: eks-devops
  readonly-crb        → Group: eks-readonly
  security-audit-crb  → Group: eks-security

RoleBindings (3):
  backend-admin-rb (ns: backend-prod)  → Group: eks-backend-admins
  backend-dev-rb   (ns: backend-prod)  → Group: eks-backend-devs
  frontend-dev-rb  (ns: frontend-prod) → Group: eks-frontend-devs
```

---

## The group names MUST match access_entries.tf

```
access_entries.tf                    k8s-manifests/
─────────────────────────────────────────────────────────────
kubernetes_groups = ["eks-devops-admins"]  ←→  name: eks-devops-admins
kubernetes_groups = ["eks-devops"]         ←→  name: eks-devops
kubernetes_groups = ["eks-backend-admins"] ←→  name: eks-backend-admins
kubernetes_groups = ["eks-backend-devs"]   ←→  name: eks-backend-devs
kubernetes_groups = ["eks-frontend-devs"]  ←→  name: eks-frontend-devs
kubernetes_groups = ["eks-readonly"]       ←→  name: eks-readonly
kubernetes_groups = ["eks-security"]       ←→  name: eks-security
```

Mismatch = group doesn't exist in K8s = 403 for everyone in that group.

---

## Apply order

```bash
# 1. Namespaces first
kubectl apply -f k8s-manifests/00-namespaces.yaml

# 2. ClusterRoles (cluster-wide, no namespace)
kubectl apply -f k8s-manifests/cluster-roles/

# 3. Roles (namespace-scoped)
kubectl apply -f k8s-manifests/roles/

# 4. ClusterRoleBindings
kubectl apply -f k8s-manifests/cluster-role-bindings/

# 5. RoleBindings
kubectl apply -f k8s-manifests/role-bindings/

# Verify everything
kubectl get clusterrole,clusterrolebinding | grep -E "devops|readonly|security"
kubectl get role,rolebinding -n backend-prod
kubectl get role,rolebinding -n frontend-prod
```

---

## Quick access matrix

```
Who      Can exec?  Can see logs?  Can see secrets?  Namespaces        Rollout restart?
───────────────────────────────────────────────────────────────────────────────────────
Alice    YES        YES            NO                ALL               YES
Bob      NO         YES            NO                ALL               YES
Frank    NO         YES            NO                ALL               YES
Charlie  YES        YES            NO                backend-prod only YES
Dave     NO         YES            NO                backend-prod only YES
Eve      NO         YES            NO                frontend-prod only NO
Grace    NO         YES            YES (list only)   ALL               NO
Henry    YES        YES            YES               ALL (system:masters)YES
```

---

## Revision notes

- RBAC is additive. No explicit deny. Omission = denied.
- Subject `kind: Group` + group name = the binding target. Not username, not IAM ARN.
- `pods/exec` resource + verb `create` = kubectl exec. Not intuitive naming but that's the API.
- `pods/log` resource + verb `get` = kubectl logs.
- `patch` on deployments = kubectl rollout restart (sends a patch to trigger re-deploy).
- Role is namespace-scoped. ClusterRole is cluster-wide. The binding type determines scope.
