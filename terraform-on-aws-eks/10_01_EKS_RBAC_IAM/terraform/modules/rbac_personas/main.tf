# ==============================================================================
# RBAC PERSONAS — FinTech Scenario
# 8 IAM users, 8 IAM roles, IAM groups, EKS access entries
#
# Chain: IAM User → IAM Group → sts:AssumeRole → IAM Role
#        → EKS Access Entry → k8s username + k8s groups
#        → ClusterRoleBinding/RoleBinding (in 03_rbac_manifests/)
# ==============================================================================

# ── IAM USERS ─────────────────────────────────────────────────────────────────

resource "aws_iam_user" "alice"   { name = "alice"   tags = merge(var.tags, { Role = "Lead DevOps" }) }
resource "aws_iam_user" "bob"     { name = "bob"     tags = merge(var.tags, { Role = "DevOps Engineer" }) }
resource "aws_iam_user" "charlie" { name = "charlie" tags = merge(var.tags, { Role = "Backend Lead" }) }
resource "aws_iam_user" "dave"    { name = "dave"    tags = merge(var.tags, { Role = "Backend Dev" }) }
resource "aws_iam_user" "eve"     { name = "eve"     tags = merge(var.tags, { Role = "Frontend Dev" }) }
resource "aws_iam_user" "frank"   { name = "frank"   tags = merge(var.tags, { Role = "On-call SRE" }) }
resource "aws_iam_user" "grace"   { name = "grace"   tags = merge(var.tags, { Role = "Security Auditor" }) }
resource "aws_iam_user" "henry"   { name = "henry"   tags = merge(var.tags, { Role = "Break-glass" }) }

# ── IAM ROLES ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "cluster_admin" {
  name = "${var.cluster_name}-cluster-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = aws_iam_user.henry.arn }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-admin-role" })
}

resource "aws_iam_role" "devops_admin" {
  name = "${var.cluster_name}-devops-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = aws_iam_user.alice.arn }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-devops-admin-role" })
}

resource "aws_iam_role" "devops" {
  name = "${var.cluster_name}-devops-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = [aws_iam_user.bob.arn, aws_iam_user.frank.arn] }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-devops-role" })
}

resource "aws_iam_role" "backend_dev_admin" {
  name = "${var.cluster_name}-backend-dev-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = aws_iam_user.charlie.arn }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-backend-dev-admin-role" })
}

resource "aws_iam_role" "backend_dev" {
  name = "${var.cluster_name}-backend-dev-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = aws_iam_user.dave.arn }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-backend-dev-role" })
}

resource "aws_iam_role" "frontend_dev" {
  name = "${var.cluster_name}-frontend-dev-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = aws_iam_user.eve.arn }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-frontend-dev-role" })
}

resource "aws_iam_role" "readonly" {
  name = "${var.cluster_name}-readonly-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-readonly-role" })
}

resource "aws_iam_role" "security" {
  name = "${var.cluster_name}-security-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = aws_iam_user.grace.arn }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-security-role" })
}

# ── EKS DESCRIBE POLICY — all roles need this to run aws eks update-kubeconfig ─

resource "aws_iam_role_policy" "eks_describe" {
  for_each = {
    cluster_admin   = aws_iam_role.cluster_admin.name
    devops_admin    = aws_iam_role.devops_admin.name
    devops          = aws_iam_role.devops.name
    backend_admin   = aws_iam_role.backend_dev_admin.name
    backend_dev     = aws_iam_role.backend_dev.name
    frontend_dev    = aws_iam_role.frontend_dev.name
    readonly        = aws_iam_role.readonly.name
    security        = aws_iam_role.security.name
  }

  name = "eks-describe-policy"
  role = each.value
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# cluster-admin gets AmazonEKSClusterAdminPolicy (break-glass only)
resource "aws_iam_role_policy_attachment" "cluster_admin_eks" {
  role       = aws_iam_role.cluster_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
}

# ── IAM GROUPS ────────────────────────────────────────────────────────────────

resource "aws_iam_group" "devops_admins"  { name = "${var.cluster_name}-devops-admins-group" }
resource "aws_iam_group" "devops"         { name = "${var.cluster_name}-devops-group" }
resource "aws_iam_group" "backend_admins" { name = "${var.cluster_name}-backend-admins-group" }
resource "aws_iam_group" "backend_devs"   { name = "${var.cluster_name}-backend-devs-group" }
resource "aws_iam_group" "frontend_devs"  { name = "${var.cluster_name}-frontend-devs-group" }
resource "aws_iam_group" "security"       { name = "${var.cluster_name}-security-group" }

resource "aws_iam_user_group_membership" "alice"   { user = aws_iam_user.alice.name;   groups = [aws_iam_group.devops_admins.name] }
resource "aws_iam_user_group_membership" "bob"     { user = aws_iam_user.bob.name;     groups = [aws_iam_group.devops.name] }
resource "aws_iam_user_group_membership" "charlie" { user = aws_iam_user.charlie.name; groups = [aws_iam_group.backend_admins.name] }
resource "aws_iam_user_group_membership" "dave"    { user = aws_iam_user.dave.name;    groups = [aws_iam_group.backend_devs.name] }
resource "aws_iam_user_group_membership" "eve"     { user = aws_iam_user.eve.name;     groups = [aws_iam_group.frontend_devs.name] }
resource "aws_iam_user_group_membership" "frank"   { user = aws_iam_user.frank.name;   groups = [aws_iam_group.devops.name] }
resource "aws_iam_user_group_membership" "grace"   { user = aws_iam_user.grace.name;   groups = [aws_iam_group.security.name] }

resource "aws_iam_group_policy" "devops_admins_assume"  { name = "assume-role"; group = aws_iam_group.devops_admins.name;  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.devops_admin.arn }] }) }
resource "aws_iam_group_policy" "devops_assume"         { name = "assume-role"; group = aws_iam_group.devops.name;         policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.devops.arn }] }) }
resource "aws_iam_group_policy" "backend_admins_assume" { name = "assume-role"; group = aws_iam_group.backend_admins.name; policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.backend_dev_admin.arn }] }) }
resource "aws_iam_group_policy" "backend_devs_assume"   { name = "assume-role"; group = aws_iam_group.backend_devs.name;   policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.backend_dev.arn }] }) }
resource "aws_iam_group_policy" "frontend_devs_assume"  { name = "assume-role"; group = aws_iam_group.frontend_devs.name;  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.frontend_dev.arn }] }) }
resource "aws_iam_group_policy" "security_assume"       { name = "assume-role"; group = aws_iam_group.security.name;       policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Resource = aws_iam_role.security.arn }] }) }

# ── EKS ACCESS ENTRIES ────────────────────────────────────────────────────────
# Bridge: IAM role ARN → k8s username + k8s groups
# Group names MUST match ClusterRoleBinding/RoleBinding subjects in 03_rbac_manifests/

resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.cluster_admin.arn
  username          = "cluster-admin"
  kubernetes_groups = ["system:masters"]
  depends_on        = [aws_iam_role.cluster_admin]
}

resource "aws_eks_access_entry" "devops_admin" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.devops_admin.arn
  username          = "devops-admin"
  kubernetes_groups = ["eks-devops-admins"]
  depends_on        = [aws_iam_role.devops_admin]
}

resource "aws_eks_access_entry" "devops" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.devops.arn
  username          = "devops"
  kubernetes_groups = ["eks-devops"]
  depends_on        = [aws_iam_role.devops]
}

resource "aws_eks_access_entry" "backend_dev_admin" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.backend_dev_admin.arn
  username          = "backend-dev-admin"
  kubernetes_groups = ["eks-backend-admins"]
  depends_on        = [aws_iam_role.backend_dev_admin]
}

resource "aws_eks_access_entry" "backend_dev" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.backend_dev.arn
  username          = "backend-dev"
  kubernetes_groups = ["eks-backend-devs"]
  depends_on        = [aws_iam_role.backend_dev]
}

resource "aws_eks_access_entry" "frontend_dev" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.frontend_dev.arn
  username          = "frontend-dev"
  kubernetes_groups = ["eks-frontend-devs"]
  depends_on        = [aws_iam_role.frontend_dev]
}

resource "aws_eks_access_entry" "readonly" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.readonly.arn
  username          = "readonly"
  kubernetes_groups = ["eks-readonly"]
  depends_on        = [aws_iam_role.readonly]
}

resource "aws_eks_access_entry" "security" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.security.arn
  username          = "security-auditor"
  kubernetes_groups = ["eks-security"]
  depends_on        = [aws_iam_role.security]
}
