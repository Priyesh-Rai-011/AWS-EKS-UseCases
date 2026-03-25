# ==============================================================================
# SECURITY GROUP — PrivateLink ENI
# Attached to the PrivateLink ENI AWS creates in your private subnet.
# Guards port 443 — the only port the EKS API server listens on.
# Nodes and pods send traffic here to reach the control plane.
# ==============================================================================
resource "aws_security_group" "private_link_sg" {
  name        = "${var.cluster_name}-privatelink-sg"
  description = "Attached to the PrivateLink ENI. Allows nodes and pods to reach EKS API server on 443."
  vpc_id      = var.vpc_id

  ingress {
    # description = "HTTPS from private node subnets to EKS API server"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }
  ingress  {
    from_port   = 443                 
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.public_subnet_cidrs
  }

  ingress {
    # description = "HTTPS within the cluster SG — cross-node communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
  }

  egress {
    # description = "All outbound nodes reach ECR S3 SSM via NAT GW"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-privatelink-sg" })
}


# ==============================================================================
# EKS CLUSTER — Control Plane
# ==============================================================================
resource "aws_eks_cluster" "basic_eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }     

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids,var.private_subnet_ids)
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


# ==============================================================================
# SYSTEM NODE GROUP
# Fixed at 2 nodes — only runs Karpenter pod + system addons.
# App pods are blocked from landing here via the taint.
# Karpenter provisions ALL application nodes separately via EC2 directly.
#
# scaling_config is intentionally fixed at 2/2/2.
# Karpenter handles all application node scaling — not this group.
# ==============================================================================
resource "aws_eks_node_group" "private_node_group" {
  cluster_name    = aws_eks_cluster.basic_eks_cluster.name
  node_group_name = "${var.cluster_name}-private-ng"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = ["t3.medium"]
  ami_type       = "AL2023_x86_64_STANDARD"
  disk_size      = 20

  scaling_config {   # It automatically creates a auto scaling group ASG when we write this config
    desired_size = 2   
    min_size     = 2
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  # labels = {
  #   role = "system"   # Karpenter Helm chart uses this to pin itself here
  # }

  # taint {
  #   key    = "CriticalAddonsOnly"
  #   value  = "true"
  #   effect = "NO_SCHEDULE"   # blocks app pods from landing on system nodes
  # }

  depends_on = [
    aws_eks_cluster.basic_eks_cluster,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_EC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore,
  ]

  tags = merge(var.tags, {
    Name                     = "${var.cluster_name}-public-node"
    # "karpenter.sh/discovery" = var.cluster_name   # Karpenter uses this tag to find subnets and SGs
  })
}


# ==============================================================================
# EKS ADDONS
# ==============================================================================

# Assigns real VPC IPs to pods via secondary ENIs on each node
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.basic_eks_cluster.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.19.5-eksbuild.3"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.basic_eks_cluster]
  tags                        = var.tags
}

# Internal DNS — my-service.namespace.svc.cluster.local
resource "aws_eks_addon" "core_dns" {
  cluster_name                = aws_eks_cluster.basic_eks_cluster.name
  addon_name                  = "coredns"
  addon_version               = "v1.12.1-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.basic_eks_cluster, aws_eks_node_group.private_node_group]
  tags                        = var.tags
}

# Manages iptables rules on each node for Service routing
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.basic_eks_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.33.0-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.basic_eks_cluster]
  tags                        = var.tags
}

# Creates and attaches EBS volumes for PersistentVolumeClaims
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.basic_eks_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.45.0-eksbuild.2"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver_role.arn
  resolve_conflicts_on_update = "PRESERVE"

  lifecycle {
    ignore_changes = [service_account_role_arn]
  }

  depends_on = [
    aws_eks_cluster.basic_eks_cluster,
    aws_eks_node_group.private_node_group,
    aws_iam_role_policy_attachment.ebs_csi_AmazonEBSCSIDriverPolicy,
  ]

  tags = var.tags
}

# Enables kubectl top node/pod and Horizontal Pod Autoscaler
resource "aws_eks_addon" "metric_server" {
  cluster_name                = aws_eks_cluster.basic_eks_cluster.name
  addon_name                  = "metrics-server"
  addon_version               = "v0.7.2-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_cluster.basic_eks_cluster, aws_eks_node_group.private_node_group]
  tags                        = var.tags
}



# =======================================================
# ==============================================================================
# EKS ACCESS ENTRY — Bastion Host IAM Role
# ==============================================================================
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.basic_eks_cluster.name
  principal_arn = var.bastion_role_arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.basic_eks_cluster]
  tags       = var.tags
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = aws_eks_cluster.basic_eks_cluster.name
  principal_arn = var.bastion_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}