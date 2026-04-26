# ==============================================================================
# SECURITY GROUP - PrivateLink ENI
# ==============================================================================
resource "aws_security_group" "private_link_sg" {
  name        = "${var.cluster_name}-privatelink-sg"
  description = "Attached to the PrivateLink ENI. Allows port 443 from nodes and bastion."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from private node subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  ingress {
    description = "HTTPS from public subnets (bastion)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.public_subnet_cidrs
  }

  ingress {
    description = "HTTPS self - cross-node communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-privatelink-sg" })
}


# ==============================================================================
# EKS CLUSTER - Control Plane
# OIDC enabled so the ebs-csi-helm module can create an IRSA role
# ==============================================================================
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    security_group_ids      = [aws_security_group.private_link_sg.id]
  }

  enabled_cluster_log_types = var.enable_cluster_logging ? [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ] : []

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_AmazonEKSVPCResourceController,
    aws_security_group.private_link_sg,
  ]

  tags = merge(var.tags, { Name = var.cluster_name })
}

# OIDC provider - required for IRSA (Helm approach uses IRSA, not Pod Identity)
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = merge(var.tags, { Name = "${var.cluster_name}-oidc" })

  depends_on = [aws_eks_cluster.this]
}


# ==============================================================================
# NODE GROUP - PUBLIC
# ==============================================================================
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-public-ng"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = var.public_subnet_ids

  instance_types = ["t3.medium"]
  ami_type       = "AL2023_x86_64_STANDARD"
  disk_size      = 20

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_EC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore,
  ]

  tags = merge(var.tags, { Name = "${var.cluster_name}-public-node" })
}


# ==============================================================================
# EKS ADDONS - Core only (EBS CSI installed separately via Helm)
# ==============================================================================
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.19.5-eksbuild.3"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.this]
  tags                        = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.33.0-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.this]
  tags                        = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = "v1.12.1-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.this, aws_eks_node_group.node_group]
  tags                        = var.tags
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "metrics-server"
  addon_version               = "v0.7.2-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.this, aws_eks_node_group.node_group]
  tags                        = var.tags
}


# ==============================================================================
# EKS ACCESS ENTRY - Bastion IAM Role gets cluster-admin
# ==============================================================================
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.bastion_role_arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.this]
  tags       = var.tags
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.bastion_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}
