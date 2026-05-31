# 05 — Developer Access (RBAC: Role + RoleBinding)

## Problem
A developer needs more than read-only but less than admin. They should access only their namespace (dev/qa) — not prod. And still no secrets, no exec.

## Concepts
- Role = namespace-scoped (unlike ClusterRole which is cluster-wide)
- RoleBinding = attaches Role to subject within one namespace
- Same developer can be bound in multiple namespaces via separate RoleBindings

```
IAM Role (eks-developer-role)
        │  (aws-auth → group "eks-developers")
        ▼
Kubernetes group: eks-developers
        │  (RoleBinding in namespace "dev")
        ▼
Role: developer-access (in namespace dev)
  ALLOW: get/list/watch/create/update pods, deployments, services
  ALLOW: get pods/log
  DENY: secrets, pods/exec, other namespaces
```

ClusterRole vs Role:
```
ClusterRole   → all namespaces
Role          → one namespace only

ClusterRoleBinding → applies ClusterRole cluster-wide
RoleBinding        → applies Role (or ClusterRole) to one namespace
```

## Implementation
Terraform creates:
- IAM Role + Trust Policy
- IAM Group + User
- aws-auth ConfigMap mapRoles entry
- Sample app deployment (UMS) in dev + qa namespaces

k8s-manifests:
- 00-namespaces.yaml (dev, qa)
- 01-role-developer.yaml
- 02-rolebinding-dev.yaml
- 03-rolebinding-qa.yaml
- 04-ums-app-deployment.yaml (test workload)

## Revision Notes
- Role + RoleBinding = namespace jail. Developer cannot see prod even if they try.
- A ClusterRole can be used in a RoleBinding — it gets namespace-scoped that way.
- This module = course steps 194–199 (StackSimplify).
