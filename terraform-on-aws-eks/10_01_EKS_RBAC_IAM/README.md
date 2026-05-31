# 10 — EKS RBAC & IAM

## Problem
How do we control who can access an EKS cluster and what they are allowed to do?

## Concepts
- IAM authenticates — answers "who are you?"
- aws-auth / Access Entry maps IAM identity to Kubernetes identity
- RBAC authorizes — answers "what can you do?"
- `kubectl auth can-i` proves access

## Implementation
| Folder | What it builds |
|--------|---------------|
| 00_access_journey | Mental model docs — read first, touch nothing |
| 01_cluster_admin_access | Cluster creator, cluster-admin ClusterRole |
| 02_iam_user_access | IAM User + aws-auth ConfigMap mapping |
| 03_iam_roles_sts_access | IAM Role + Trust Policy + STS AssumeRole |
| 04_readonly_access | RBAC ClusterRole/ClusterRoleBinding, read-only |
| 05_developer_access | RBAC Role/RoleBinding, namespace-scoped |
| 06_validation | kubectl auth can-i tests, screenshots |

## Revision Notes
- IAM decides WHO you are
- RBAC decides WHAT you can do
- aws-auth / Access Entry is the bridge between them
- Modules 01–03 = authentication. Modules 04–05 = authorization.
