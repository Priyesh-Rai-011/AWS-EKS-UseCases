# 02 — EKS Access Entries

Code lives in: `../terraform/access_entries.tf`

---

## What this does

Access Entries are the bridge between AWS IAM and Kubernetes RBAC.

```
IAM Role ARN
  → aws_eks_access_entry
      → kubernetes username  (appears in EKS audit logs)
      → kubernetes groups    (RBAC bindings target these groups)
```

Without an access entry, an IAM role can authenticate to AWS but gets a 403 from the Kubernetes API server — the cluster doesn't know what identity to assign.

---

## The 8 mappings

```
IAM Role                    k8s username        k8s groups
──────────────────────────────────────────────────────────────────────
eks-cluster-admin-role    → "cluster-admin"   → ["system:masters"]
eks-devops-admin-role     → "devops-admin"    → ["eks-devops-admins"]
eks-devops-role           → "devops"          → ["eks-devops"]
eks-backend-dev-admin-role→ "backend-dev-admin"→["eks-backend-admins"]
eks-backend-dev-role      → "backend-dev"     → ["eks-backend-devs"]
eks-frontend-dev-role     → "frontend-dev"    → ["eks-frontend-devs"]
eks-readonly-role         → "readonly"        → ["eks-readonly"]
eks-security-role         → "security-auditor"→ ["eks-security"]
```

---

## system:masters — special case

`eks-cluster-admin-role` maps to group `system:masters`. This is a built-in Kubernetes group. Anyone in it gets full cluster-admin automatically, with NO RBAC manifest needed.

```
system:masters → automatically bound to cluster-admin ClusterRole by Kubernetes
               → full get/list/watch/create/update/delete everywhere
               → can modify RBAC itself
               → break-glass only (Henry)
```

All other groups are custom (`eks-devops-admins`, `eks-backend-devs`, etc.) — they need explicit ClusterRoleBindings or RoleBindings in `03_rbac_manifests/`.

---

## aws-auth ConfigMap vs Access Entries

| | aws-auth ConfigMap | EKS Access Entries |
|--|--|--|
| How | Edit ConfigMap in kube-system | Terraform resource |
| API | kubectl edit | AWS API |
| Type | Legacy | Modern (EKS API) |
| Version | All EKS | EKS 1.23+ |
| State | Inside cluster | AWS managed |

This repo uses Access Entries. Never mix both in the same cluster.

---

## Apply + verify

```bash
cd terraform-on-aws-eks/10_01_EKS_RBAC_IAM/terraform
terraform apply

# Verify access entries created
aws eks list-access-entries \
  --cluster-name $(terraform output -raw cluster_name) \
  --region ap-south-1

# Check one entry
aws eks describe-access-entry \
  --cluster-name $(terraform output -raw cluster_name) \
  --principal-arn $(terraform output -json iam_role_arns | jq -r '.devops_admin') \
  --region ap-south-1
```

---

## Revision notes

- Access Entry = the IAM → Kubernetes identity mapping.
- `kubernetes_groups` here MUST match subject `name:` in RoleBindings/ClusterRoleBindings.
- `system:masters` needs no RBAC manifest — it's a built-in K8s privilege escalation group.
- Username appears in EKS audit logs. Group is what RBAC actually checks.
- This file references `aws_iam_role.*` outputs from `iam.tf` — apply `iam.tf` first.
