# 02 — IAM Identity Center (Conceptual)

> No Terraform implementation. No hands-on required. Conceptual understanding only.
> Real implementation needs AWS Organizations + Control Tower setup.

## Problem
Enterprises have hundreds of developers. Creating individual IAM Users per person doesn't scale. IAM Identity Center centralizes access across all AWS accounts.

## The Enterprise Flow

```
Google Workspace (IdP)
        │  SCIM sync (user groups pushed to AWS)
        ▼
IAM Identity Center
        │  Permission Set assigned to dev-account
        ▼
AWSReservedSSO_<PermissionSet>_xxxx IAM Role (in dev-account)
        │  EKS Access Entry maps this role ARN
        ▼
Kubernetes group: eks-developers
        │  RoleBinding
        ▼
RBAC permissions
```

## Key Terms
- **Permission Set** = a named collection of IAM policies, centrally defined
- **Account Assignment** = which Permission Set applies to which account for which group
- **AWSReservedSSO_*** = the IAM role automatically created in each account
- **SCIM** = protocol that syncs user/group changes from the IdP to Identity Center

## Why Your Company Uses This
- Developers log into AWS via Google SSO — no IAM User credentials
- When someone leaves: remove from Google group → access revoked everywhere automatically
- One Permission Set definition → applies to dev, QA, prod accounts consistently

## Revision Notes
- The IAM role ARN to put in EKS Access Entry = the AWSReservedSSO_* role in THAT account.
- Identity Center lives in the management/audit account. Roles are in workload accounts.
- You already understand the EKS side (Access Entries). This just changes how the IAM Role is created.
