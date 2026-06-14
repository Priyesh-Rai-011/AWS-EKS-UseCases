# Cluster Creator — The First Admin

## Problem
A freshly created EKS cluster has no visible admin user configured. Yet someone can access it immediately. Why?

## Concepts
The IAM principal that runs `terraform apply` (or `eksctl create cluster`) is automatically granted `cluster-admin` by EKS. This is hardcoded — not visible in aws-auth, not a RoleBinding you can see.

```
terraform apply (runs as IAM Role X)
        │
        ▼
EKS cluster created
        │
        ▼
IAM Role X = silent cluster-admin (built into EKS control plane)
        │
        ▼
No entry needed in aws-auth
```

### Why this matters
- If your Terraform runs as a CI/CD role, that role = cluster admin. Guard it.
- If you lose access to that IAM role, you lose the silent admin. Other admins must exist.
- The cluster creator identity does NOT appear in `kubectl get clusterrolebindings`.

## Revision Notes
- Cluster creator = automatic cluster-admin, invisible in RBAC objects.
- Always add at least one explicit admin via aws-auth/Access Entry immediately after creation.
- This is why module 01 teaches admin access first.
