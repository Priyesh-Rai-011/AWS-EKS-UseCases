# 07 — ClusterRole vs Role: The Scope Decision

One question drives the decision:

```
Does this identity need to see/act across ALL namespaces?
  YES → ClusterRole + ClusterRoleBinding
  NO  → Role + RoleBinding (scoped to one namespace)
```

---

## The two types and what they control

```
ClusterRole + ClusterRoleBinding
  → identity can act in ALL namespaces
  → also covers non-namespaced resources: nodes, PVs, namespaces themselves

Role + RoleBinding
  → identity can act in ONE namespace only
  → blast radius contained: mistakes stay inside that namespace
```

---

## Applied to the FinTech cluster

```
IAM Role                    Scope              Type                  Why
────────────────────────────────────────────────────────────────────────────────────
eks-cluster-admin-role      cluster-wide       ClusterRole + CRB     nodes, full control
eks-devops-admin-role       cluster-wide       ClusterRole + CRB     incidents happen anywhere
eks-devops-role             cluster-wide       ClusterRole + CRB     SRE on-call needs all ns
eks-backend-dev-admin-role  backend-prod only  Role + RB             blast radius reduction
eks-backend-dev-role        backend-prod only  Role + RB             junior dev, own ns only
eks-frontend-dev-role       frontend-prod only Role + RB             team isolation
eks-readonly-role           cluster-wide       ClusterRole + CRB     auditors need full picture
eks-security-role           cluster-wide       ClusterRole + CRB     RBAC audit is cluster-wide
```

---

## The blast radius principle

If Dave (backend-dev) runs `kubectl delete deployment --all`:

```
WITHOUT namespace scoping (ClusterRole):
  deletes deployments in backend-prod ✗
  deletes deployments in frontend-prod ✗
  deletes deployments in monitoring ✗
  takes down the whole cluster ✗

WITH namespace scoping (Role in backend-prod):
  deletes deployments in backend-prod ✗  ← damage contained here
  frontend-prod untouched ✓
  monitoring untouched ✓
```

Role + RoleBinding = the mistake can only hurt your own namespace.

---

## Why devops stays cluster-wide

Alice (devops-admin) gets paged at 3am. payment-service is down. She doesn't know which namespace has the problem until she looks.

```
If Alice had Role scoped to backend-prod only:
  kubectl get pods -n frontend-prod → DENIED
  kubectl logs pod/nginx -n frontend-prod → DENIED
  kubectl describe node ip-10-0-1-45 → DENIED (nodes are non-namespaced)
```

Operations people handle incidents everywhere. Namespace scoping makes on-call useless.

---

## Why security stays cluster-wide

Grace (security-auditor) asks: "Which service accounts have cluster-admin bindings?"

```
kubectl get clusterrolebindings -A
```

That question has no meaning scoped to one namespace. Security audit is inherently cluster-wide — you're checking the whole posture, not one team's corner.

---

## The resource split in YAML

ClusterRole for devops-admin (cluster-wide, exec allowed):
```yaml
kind: ClusterRole
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "nodes", "namespaces", "events"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# secrets NOT listed → no access
```

Role for backend-dev (namespace-scoped, no exec):
```yaml
kind: Role          ← not ClusterRole
metadata:
  namespace: backend-prod   ← required for Role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "patch"]   ← patch = rollout restart
# pods/exec NOT listed → no exec
# secrets NOT listed → no access
```

---

## Secret protection — no special mechanism

Secrets are a Kubernetes resource like any other. Protection = don't list them in rules.

```yaml
# This role CANNOT see secrets:
rules:
- apiGroups: [""]
  resources: ["pods", "services"]   ← secrets not here → denied
  verbs: ["get", "list", "watch"]

# This role CAN see secrets (security team only):
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

Only `eks-security-role` has secrets in its rules. Everyone else — omission = denial.
