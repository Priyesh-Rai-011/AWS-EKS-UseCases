# 03 — IAM Roles + STS AssumeRole

## Problem
IAM Users have long-term credentials — a security risk. Production environments use IAM Roles with temporary credentials via STS. How does a human assume a role and use it to access EKS?

## Concepts
- IAM Role = no long-term credentials, accessed via STS AssumeRole
- Trust Policy = who is allowed to assume this role
- STS = Security Token Service, issues temporary credentials (1hr default)
- IAM Group + Group Policy = grants users permission to assume the role

```
IAM User (eksadmin1)
  member of IAM Group "eks-admins"
        │  (Group Policy: sts:AssumeRole on eks-admin-role)
        ▼
STS AssumeRole
        │  (returns temp AccessKeyId + SecretKey + SessionToken)
        ▼
Temporary credentials (1 hour)
        │  (EKS checks aws-auth mapRoles)
        ▼
Kubernetes group: system:masters
        │
        ▼
Full cluster access
```

## Implementation
Terraform creates:
- IAM Role with Trust Policy (trusts IAM User ARN)
- IAM Policy: full EKS access
- IAM Group + Group Policy: sts:AssumeRole permission
- IAM User + Group membership
- aws-auth ConfigMap mapRoles entry

k8s-manifests:
- aws-auth ConfigMap with mapRoles entry

## Revision Notes
- Roles = temporary credentials. Safer than IAM Users for EKS access.
- Trust Policy controls WHO can assume the role — scope it tightly.
- `aws sts assume-role` returns 3 values: export all 3 as env vars before kubectl.
- This module = course steps 173–187 (StackSimplify).
