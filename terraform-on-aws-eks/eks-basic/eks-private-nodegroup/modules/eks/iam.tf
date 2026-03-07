# ==============================================================================
# ROLE 1 — EKS CLUSTER ROLE
# Assumed by: eks.amazonaws.com (the control plane)
# Used to: create the PrivateLink ENI in your subnet,
#          manage its SG, create LBs for LoadBalancer Services
# ==============================================================================
resource "aws_iam_role" "eks_cluster_role" {
  name        = "${var.cluster_name}-cluster-role"
  description = "Assumed by EKS control plane to manage AWS resources in your VPC"

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
# ROLE 2 — SYSTEM NODE GROUP ROLE
# Assumed by: ec2.amazonaws.com (your EC2 worker nodes)
# Used by: system nodes that run Karpenter + addons
# When you add Karpenter later, these same nodes run the Karpenter pod
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

# Node registers with and joins the EKS cluster
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

# VPC CNI assigns real VPC IPs to pods via secondary ENIs
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

# Node pulls container images from ECR
resource "aws_iam_role_policy_attachment" "node_EC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# SSM Session Manager — shell into nodes without port 22
resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group_role.name
}


# ==============================================================================
# ROLE 3 — EBS CSI DRIVER ROLE
# Assumed by: eks.amazonaws.com (on behalf of the EBS CSI addon)
# Used to: create and attach EBS volumes when pods request PersistentVolumeClaims
# Separate from node role — only needs EBS permissions, nothing else
# Wired to the addon via service_account_role_arn in main.tf
# ==============================================================================
resource "aws_iam_role" "ebs_csi_driver_role" {
  name        = "${var.cluster_name}-ebs-csi-role"
  description = "Assumed by EBS CSI Driver addon to create and manage EBS volumes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-ebs-csi-role" })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}