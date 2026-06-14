# aws-auth ConfigMap vs EKS Access Entries

## Problem
There are two ways to map IAM identities to Kubernetes. The old way is fragile. The new way is API-driven. You will see both in real clusters.

## Concepts

### aws-auth ConfigMap (legacy)
```yaml
# kube-system/aws-auth
mapRoles:
- rolearn: arn:aws:iam::123456789:role/dev-role
  username: dev-user
  groups:
  - eks-developers
```
- Stored as a ConfigMap in kube-system namespace
- One wrong edit = entire cluster locked out
- No audit trail for changes
- Still the default on older clusters

### EKS Access Entries (modern — 2024+)
```bash
aws eks create-access-entry \
  --cluster-name my-cluster \
  --principal-arn arn:aws:iam::123456789:role/dev-role \
  --kubernetes-groups eks-developers
```
- Stored in AWS (not in the cluster)
- API-driven — Terraform manages it cleanly
- CloudTrail audit trail on every change
- AWS is pushing all customers toward this

| | aws-auth | Access Entries |
|-|----------|----------------|
| Storage | K8s ConfigMap | AWS API |
| Risk | Edit = lockout | Managed safely |
| Audit | None | CloudTrail |
| Terraform resource | kubernetes_config_map | aws_eks_access_entry |

## Revision Notes
- This course teaches aws-auth first (for understanding). Production is moving to Access Entries.
- Module 10_02 covers Access Entries as the modern approach.
- Both map the same thing: IAM principal → Kubernetes group.
