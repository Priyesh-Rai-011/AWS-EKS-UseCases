# ==============================================================================
# RBAC PERSONAS — FinTech Scenario
# 8 IAM users, 8 IAM roles, IAM groups, EKS access entries
#
# Chain: IAM User → IAM Group → sts:AssumeRole → IAM Role
#        → EKS Access Entry → k8s username + k8s groups
#        → ClusterRoleBinding/RoleBinding (in 03_rbac_manifests/)
#
# Adding a persona = one map entry. Zero new resource blocks.
# ==============================================================================

locals {
  personas = {
    alice   = "Lead DevOps"
    bob     = "DevOps Engineer"
    charlie = "Backend Lead"
    dave    = "Backend Dev"
    eve     = "Frontend Dev"
    frank   = "On-call SRE"
    grace   = "Security Auditor"
    henry   = "Break-glass"
  }

  # principals = [] → trust account root (readonly pattern, no specific user)
  roles = {
    cluster_admin     = { suffix = "cluster-admin-role", principals = ["henry"] }
    devops_admin      = { suffix = "devops-admin-role", principals = ["alice"] }
    devops            = { suffix = "devops-role", principals = ["bob", "frank"] }
    backend_dev_admin = { suffix = "backend-dev-admin-role", principals = ["charlie"] }
    backend_dev       = { suffix = "backend-dev-role", principals = ["dave"] }
    frontend_dev      = { suffix = "frontend-dev-role", principals = ["eve"] }
    readonly          = { suffix = "readonly-role", principals = [] }
    security          = { suffix = "security-role", principals = ["grace"] }
  }

  groups = {
    devops_admins  = { suffix = "devops-admins-group", role_key = "devops_admin", members = ["alice"] }
    devops         = { suffix = "devops-group", role_key = "devops", members = ["bob", "frank"] }
    backend_admins = { suffix = "backend-admins-group", role_key = "backend_dev_admin", members = ["charlie"] }
    backend_devs   = { suffix = "backend-devs-group", role_key = "backend_dev", members = ["dave"] }
    frontend_devs  = { suffix = "frontend-devs-group", role_key = "frontend_dev", members = ["eve"] }
    security       = { suffix = "security-group", role_key = "security", members = ["grace"] }
  }

  # Flatten group members → { username = group_key }
  group_memberships = merge([
    for gk, g in local.groups : {
      for member in g.members : member => gk
    }
  ]...)

  # cluster_admin excluded — uses aws_eks_access_policy_association (AmazonEKSClusterAdminPolicy)
  # EKS API blocks system:masters in kubernetes_groups on standard access entries
  access_entries = {
    devops_admin      = { username = "devops-admin", k8s_groups = ["eks-devops-admins"] }
    devops            = { username = "devops", k8s_groups = ["eks-devops"] }
    backend_dev_admin = { username = "backend-dev-admin", k8s_groups = ["eks-backend-admins"] }
    backend_dev       = { username = "backend-dev", k8s_groups = ["eks-backend-devs"] }
    frontend_dev      = { username = "frontend-dev", k8s_groups = ["eks-frontend-devs"] }
    readonly          = { username = "readonly", k8s_groups = ["eks-readonly"] }
    security          = { username = "security-auditor", k8s_groups = ["eks-security"] }
  }
}

# ── IAM USERS ─────────────────────────────────────────────────────────────────

resource "aws_iam_user" "personas" {
  for_each = local.personas
  name     = each.key
  tags     = merge(var.tags, { Role = each.value })
}

# ── IAM ROLES ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "roles" {
  for_each = local.roles
  name     = "${var.cluster_name}-${each.value.suffix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = length(each.value.principals) > 0 ? [for p in each.value.principals : aws_iam_user.personas[p].arn] : ["arn:aws:iam::${var.account_id}:root"]
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-${each.value.suffix}" })
}

# ── EKS DESCRIBE POLICY — all roles need this to run aws eks update-kubeconfig ─

resource "aws_iam_role_policy" "eks_describe" {
  for_each = aws_iam_role.roles
  name     = "eks-describe-policy"
  role     = each.value.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# Henry: direct user policy — no group, break-glass means out-of-band access only
resource "aws_iam_user_policy" "henry_assume_cluster_admin" {
  name = "assume-cluster-admin"
  user = aws_iam_user.personas["henry"].name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.roles["cluster_admin"].arn }]
  })
}

# ── IAM GROUPS ────────────────────────────────────────────────────────────────

resource "aws_iam_group" "groups" {
  for_each = local.groups
  name     = "${var.cluster_name}-${each.value.suffix}"
}

resource "aws_iam_user_group_membership" "personas" {
  for_each = local.group_memberships
  user     = aws_iam_user.personas[each.key].name
  groups   = [aws_iam_group.groups[each.value].name]
}

resource "aws_iam_group_policy" "assume_role" {
  for_each = local.groups
  name     = "assume-role"
  group    = aws_iam_group.groups[each.key].name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.roles[each.value.role_key].arn }]
  })
}

# ── EKS ACCESS ENTRIES ────────────────────────────────────────────────────────
# Bridge: IAM role ARN → k8s username + k8s groups
# Group names MUST match ClusterRoleBinding/RoleBinding subjects in 03_rbac_manifests/

resource "aws_eks_access_entry" "roles" {
  for_each          = local.access_entries
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.roles[each.key].arn
  user_name         = each.value.username
  kubernetes_groups = each.value.k8s_groups
  depends_on        = [aws_iam_role.roles]
}

# cluster_admin: EKS managed policy, not k8s group binding
# system:masters is reserved — must use AmazonEKSClusterAdminPolicy via access policy association
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.roles["cluster_admin"].arn
  user_name     = "cluster-admin"
  depends_on    = [aws_iam_role.roles]
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.roles["cluster_admin"].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admin]
}
