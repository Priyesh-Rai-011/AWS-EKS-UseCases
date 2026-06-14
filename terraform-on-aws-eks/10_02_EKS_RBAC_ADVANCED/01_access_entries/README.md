# 01 — EKS Access Entries (Modern aws-auth Replacement)

## Problem
aws-auth ConfigMap is a K8s ConfigMap in kube-system. One bad edit locks out the entire cluster. There's no audit trail. AWS built Access Entries to fix this.

## Concepts
```
aws-auth (legacy)                  Access Entries (modern)
─────────────────────────────────  ──────────────────────────────────
Stored in: K8s etcd                Stored in: AWS API
Edit risk: cluster lockout         Edit risk: none (API-driven)
Audit: none                        Audit: CloudTrail
Terraform: kubernetes_config_map   Terraform: aws_eks_access_entry
Recovery: need cluster access      Recovery: AWS console/CLI
```

Terraform resources:
```hcl
resource "aws_eks_access_entry" "developer" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.developer.arn
  kubernetes_groups = ["eks-developers"]
}
```

## Implementation
Same cluster as module 10. Migration only — no new VPC/EKS.
Terraform replaces kubernetes_config_map with aws_eks_access_entry.

## Revision Notes
- Access Entries require EKS cluster auth mode = API or API_AND_CONFIG_MAP.
- Existing aws-auth entries are not deleted when you add Access Entries — clean up manually.
- This is what 10_02 adds on top of module 10.
