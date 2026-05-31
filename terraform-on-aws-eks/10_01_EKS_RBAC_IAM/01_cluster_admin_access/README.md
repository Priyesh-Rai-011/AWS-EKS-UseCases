# 01 — Cluster Admin Access

## Problem
A new EKS cluster exists. Only the Terraform executor can access it. How do we grant another IAM principal full cluster-admin access explicitly — so access is visible, auditable, and not tied to a single CI/CD role?

## Concepts
- Cluster creator = silent cluster-admin (see 00_access_journey/03)
- `cluster-admin` = built-in Kubernetes ClusterRole with all permissions
- aws-auth ConfigMap maps IAM principal → Kubernetes `system:masters` group
- `system:masters` group = bound to `cluster-admin` ClusterRole by Kubernetes itself

```
IAM User / Role (eksadmin1)
        │  (aws-auth mapRoles)
        ▼
Kubernetes group: system:masters
        │  (built-in ClusterRoleBinding)
        ▼
ClusterRole: cluster-admin
        │
        ▼
Full cluster access
```

## Implementation
Terraform creates:
- VPC + EKS cluster (modules 01_vpc, 02_eks, 03_bastion)
- IAM User with programmatic access
- aws-auth ConfigMap entry mapping that user to system:masters

k8s-manifests:
- aws-auth ConfigMap (reference — Terraform manages this)

## Revision Notes
- `system:masters` group = cluster-admin. Never assign this to developers.
- aws-auth is in `kube-system` namespace. One bad YAML edit = lockout.
- This module = course steps 157–162 (StackSimplify).
