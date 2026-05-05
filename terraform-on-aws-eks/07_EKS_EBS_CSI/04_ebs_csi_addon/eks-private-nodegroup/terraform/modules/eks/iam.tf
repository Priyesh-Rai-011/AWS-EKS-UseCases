# ==============================================================================
# ROLE 1 — EKS CLUSTER ROLE
# Assumed by the EKS control plane to manage ENIs, SGs, and LBs in the VPC
# ==============================================================================
resource "aws_iam_role" "eks_cluster_role" {
  name        = "${var.cluster_name}-cluster-role"
  description = "Assumed by EKS control plane to manage AWS resources in the VPC"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}


# ==============================================================================
# ROLE 2 — NODE GROUP ROLE
# Assumed by EC2 worker nodes to join the cluster and pull images
# ==============================================================================
resource "aws_iam_role" "eks_node_group_role" {
  name        = "${var.cluster_name}-node-role"
  description = "Assumed by EC2 worker nodes to join the cluster and access AWS services"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-node-role" })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_EC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group_role.name
}


# ==============================================================================
# ROLE 3 — EBS CSI DRIVER ROLE
# Assumed via Pod Identity (pods.eks.amazonaws.com) by the ebs-csi-controller-sa
# Used to create and attach EBS volumes for PersistentVolumeClaims
# ==============================================================================
resource "aws_iam_role" "ebs_csi_driver_role" {
  name        = "${var.cluster_name}-ebs-csi-role"
  description = "Assumed by EBS CSI Driver pod via Pod Identity to manage EBS volumes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-ebs-csi-role" })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}


# ==============================================================================
# ROLE 4 — UMS APP ROLE
# Assumed via Pod Identity by the ums-app service account in the ums-app namespace.
# Grants read-only access to the UMS Secrets Manager secret (DB credentials).
# ==============================================================================
resource "aws_iam_role" "ums_app_role" {
  name        = "${var.cluster_name}-ums-app-role"
  description = "Assumed by ums-app pods via Pod Identity to read DB credentials from Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-ums-app-role" })
}

resource "aws_iam_policy" "ums_secrets_read" {
  name        = "${var.cluster_name}-ums-secrets-read"
  description = "Allows ums-app pods to read the postgres credentials secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      # Exact ARN from the secrets module — no wildcards, least-privilege
      Resource = var.postgres_secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ums_secrets_read" {
  policy_arn = aws_iam_policy.ums_secrets_read.arn
  role       = aws_iam_role.ums_app_role.name
}

# Wire ums-app ServiceAccount in ums-app namespace to the IAM role via Pod Identity
resource "aws_eks_pod_identity_association" "ums_app" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "ums-app"
  service_account = "ums-app-sa"
  role_arn        = aws_iam_role.ums_app_role.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
