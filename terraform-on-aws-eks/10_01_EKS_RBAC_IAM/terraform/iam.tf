# =============================================================================
# IAM USERS
# =============================================================================
# 8 users — one per persona in the FinTech scenario
# Each user gets no direct EKS permissions.
# Permissions come only via STS AssumeRole → IAM Role → EKS Access Entry → RBAC

resource "aws_iam_user" "alice" {
  name = "alice"
  tags = { Role = "Lead DevOps" }
}

resource "aws_iam_user" "bob" {
  name = "bob"
  tags = { Role = "DevOps Engineer" }
}

resource "aws_iam_user" "charlie" {
  name = "charlie"
  tags = { Role = "Backend Lead" }
}

resource "aws_iam_user" "dave" {
  name = "dave"
  tags = { Role = "Backend Dev" }
}

resource "aws_iam_user" "eve" {
  name = "eve"
  tags = { Role = "Frontend Dev" }
}

resource "aws_iam_user" "frank" {
  name = "frank"
  tags = { Role = "On-call SRE" }
}

resource "aws_iam_user" "grace" {
  name = "grace"
  tags = { Role = "Security Auditor" }
}

resource "aws_iam_user" "henry" {
  name = "henry"
  tags = { Role = "Break-glass Admin" }
}

# =============================================================================
# IAM ROLES — one per access pattern
# No role gets AmazonEKSClusterAdminPolicy except cluster-admin (Henry only)
# =============================================================================

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# --- cluster-admin (Henry — break-glass only, never used day-to-day) ---
resource "aws_iam_role" "cluster_admin" {
  name = "eks-cluster-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_user.henry.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_admin_eks" {
  role       = aws_iam_role.cluster_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
}

# --- devops-admin (Alice — cluster-wide, exec allowed) ---
resource "aws_iam_role" "devops_admin" {
  name = "eks-devops-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_user.alice.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "devops_admin_eks" {
  name = "eks-devops-admin-policy"
  role = aws_iam_role.devops_admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# --- devops-viewer (Bob + Frank — cluster-wide, no exec) ---
resource "aws_iam_role" "devops" {
  name = "eks-devops-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = [aws_iam_user.bob.arn, aws_iam_user.frank.arn] }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "devops_eks" {
  name = "eks-devops-policy"
  role = aws_iam_role.devops.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# --- backend-dev-admin (Charlie — namespace: backend-prod, exec allowed) ---
resource "aws_iam_role" "backend_dev_admin" {
  name = "eks-backend-dev-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_user.charlie.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "backend_dev_admin_eks" {
  name = "eks-backend-dev-admin-policy"
  role = aws_iam_role.backend_dev_admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# --- backend-dev (Dave — namespace: backend-prod, no exec) ---
resource "aws_iam_role" "backend_dev" {
  name = "eks-backend-dev-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_user.dave.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "backend_dev_eks" {
  name = "eks-backend-dev-policy"
  role = aws_iam_role.backend_dev.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# --- frontend-dev (Eve — namespace: frontend-prod) ---
resource "aws_iam_role" "frontend_dev" {
  name = "eks-frontend-dev-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_user.eve.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "frontend_dev_eks" {
  name = "eks-frontend-dev-policy"
  role = aws_iam_role.frontend_dev.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# --- readonly (cluster-wide, no write, no exec, no secrets) ---
resource "aws_iam_role" "readonly" {
  name = "eks-readonly-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      # open to any user in this account for auditor/stakeholder use
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "readonly_eks" {
  name = "eks-readonly-policy"
  role = aws_iam_role.readonly.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# --- security-auditor (Grace — cluster-wide, secrets list allowed) ---
resource "aws_iam_role" "security" {
  name = "eks-security-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_user.grace.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "security_eks" {
  name = "eks-security-policy"
  role = aws_iam_role.security.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# =============================================================================
# IAM GROUPS — grant sts:AssumeRole per team
# Users have no direct permissions; group policy is the only way they get access
# =============================================================================

resource "aws_iam_group" "devops_admins" {
  name = "eks-devops-admins-group"
}

resource "aws_iam_group" "devops" {
  name = "eks-devops-group"
}

resource "aws_iam_group" "backend_admins" {
  name = "eks-backend-admins-group"
}

resource "aws_iam_group" "backend_devs" {
  name = "eks-backend-devs-group"
}

resource "aws_iam_group" "frontend_devs" {
  name = "eks-frontend-devs-group"
}

resource "aws_iam_group" "security" {
  name = "eks-security-group"
}

# Group memberships
resource "aws_iam_user_group_membership" "alice" {
  user   = aws_iam_user.alice.name
  groups = [aws_iam_group.devops_admins.name]
}

resource "aws_iam_user_group_membership" "bob" {
  user   = aws_iam_user.bob.name
  groups = [aws_iam_group.devops.name]
}

resource "aws_iam_user_group_membership" "charlie" {
  user   = aws_iam_user.charlie.name
  groups = [aws_iam_group.backend_admins.name]
}

resource "aws_iam_user_group_membership" "dave" {
  user   = aws_iam_user.dave.name
  groups = [aws_iam_group.backend_devs.name]
}

resource "aws_iam_user_group_membership" "eve" {
  user   = aws_iam_user.eve.name
  groups = [aws_iam_group.frontend_devs.name]
}

resource "aws_iam_user_group_membership" "frank" {
  user   = aws_iam_user.frank.name
  groups = [aws_iam_group.devops.name]
}

resource "aws_iam_user_group_membership" "grace" {
  user   = aws_iam_user.grace.name
  groups = [aws_iam_group.security.name]
}

# Group policies — each group can only assume its assigned role
resource "aws_iam_group_policy" "devops_admins_assume" {
  name  = "assume-devops-admin-role"
  group = aws_iam_group.devops_admins.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.devops_admin.arn
    }]
  })
}

resource "aws_iam_group_policy" "devops_assume" {
  name  = "assume-devops-role"
  group = aws_iam_group.devops.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.devops.arn
    }]
  })
}

resource "aws_iam_group_policy" "backend_admins_assume" {
  name  = "assume-backend-admin-role"
  group = aws_iam_group.backend_admins.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.backend_dev_admin.arn
    }]
  })
}

resource "aws_iam_group_policy" "backend_devs_assume" {
  name  = "assume-backend-dev-role"
  group = aws_iam_group.backend_devs.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.backend_dev.arn
    }]
  })
}

resource "aws_iam_group_policy" "frontend_devs_assume" {
  name  = "assume-frontend-dev-role"
  group = aws_iam_group.frontend_devs.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.frontend_dev.arn
    }]
  })
}

resource "aws_iam_group_policy" "security_assume" {
  name  = "assume-security-role"
  group = aws_iam_group.security.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.security.arn
    }]
  })
}
