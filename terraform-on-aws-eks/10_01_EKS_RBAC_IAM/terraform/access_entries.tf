# =============================================================================
# EKS ACCESS ENTRIES
# =============================================================================
# This is the bridge: IAM Role ARN → Kubernetes username + Kubernetes groups
#
# The groups set here MUST match the group names used in ClusterRoleBindings
# and RoleBindings in 03_rbac_manifests/k8s-manifests/
#
# Flow:
#   IAM Role ARN
#     → aws_eks_access_entry (this file)
#         → kubernetes username (for audit logs)
#         → kubernetes groups (for RBAC binding targets)
#             → ClusterRoleBinding/RoleBinding in cluster (kubectl apply)
#                 → ClusterRole/Role defines verbs
# =============================================================================

locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
}

# Henry — break-glass only. system:masters = full cluster-admin, no RBAC manifest needed.
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.cluster_admin.arn
  username      = "cluster-admin"
  kubernetes_groups = ["system:masters"]
}

# Alice — devops-admin, cluster-wide, exec allowed
resource "aws_eks_access_entry" "devops_admin" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.devops_admin.arn
  username      = "devops-admin"
  kubernetes_groups = ["eks-devops-admins"]
}

# Bob + Frank — devops-viewer, cluster-wide, no exec
resource "aws_eks_access_entry" "devops" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.devops.arn
  username      = "devops"
  kubernetes_groups = ["eks-devops"]
}

# Charlie — backend-admin, namespace: backend-prod, exec allowed
resource "aws_eks_access_entry" "backend_dev_admin" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.backend_dev_admin.arn
  username      = "backend-dev-admin"
  kubernetes_groups = ["eks-backend-admins"]
}

# Dave — backend-dev, namespace: backend-prod, no exec
resource "aws_eks_access_entry" "backend_dev" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.backend_dev.arn
  username      = "backend-dev"
  kubernetes_groups = ["eks-backend-devs"]
}

# Eve — frontend-dev, namespace: frontend-prod only
resource "aws_eks_access_entry" "frontend_dev" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.frontend_dev.arn
  username      = "frontend-dev"
  kubernetes_groups = ["eks-frontend-devs"]
}

# Readonly — cluster-wide, no write, no exec, no secrets
resource "aws_eks_access_entry" "readonly" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.readonly.arn
  username      = "readonly"
  kubernetes_groups = ["eks-readonly"]
}

# Grace — security-auditor, cluster-wide, secrets list allowed
resource "aws_eks_access_entry" "security" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.security.arn
  username      = "security-auditor"
  kubernetes_groups = ["eks-security"]
}
