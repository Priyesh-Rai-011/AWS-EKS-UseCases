# 04 — Read-Only Access (RBAC: ClusterRole)

## Problem
Not everyone needs admin access. A developer should be able to see pods and logs — but should not be able to delete resources or read secrets. How do we enforce this?

## Concepts
- ClusterRole = cluster-wide permission set (all namespaces)
- ClusterRoleBinding = attaches ClusterRole to a subject (user/group)
- Kubernetes RBAC is additive — no explicit deny. If a verb isn't granted, it's denied.

```
IAM Role (eks-readonly-role)
        │  (aws-auth mapRoles → group "eks-readonly")
        ▼
Kubernetes group: eks-readonly
        │  (ClusterRoleBinding)
        ▼
ClusterRole: eks-readonly
  ALLOW: get/list/watch pods, deployments, services, configmaps, events
  ALLOW: get pods/log
  DENY (by omission): secrets, pods/exec, rolebindings
```

## Implementation
Terraform creates:
- IAM Role + Trust Policy
- IAM Group + User
- aws-auth ConfigMap mapRoles entry

k8s-manifests:
- 01-clusterrole-readonly.yaml
- 02-clusterrolebinding-readonly.yaml

## Revision Notes
- RBAC has no explicit DENY. Omitting a verb = denied.
- Built-in `view` ClusterRole exists but includes too many resources. Define custom.
- `kubectl auth can-i get secrets --as system:serviceaccount:default:test` to test.
- This module = course steps 188–193 (StackSimplify).
