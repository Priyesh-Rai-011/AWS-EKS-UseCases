# # =+=+=+=+=+=+=+=+=+=+=+=+=+=+
resource "aws_eks_cluster" "simple-eks-cluster" {
       
}




















# # This is the main.tf file for the EKS cluster with a public node group.
# # It defines the EKS cluster and the public node group, along with necessary IAM roles and security groups.
# # --------------------------------------------------------------------------
# # EKS Cluster
# resource "aws_eks_cluster" "this" {
#     name     = "${var.name}-eks-cluster"
#     role_arn = aws_iam_role.eks_cluster_role.arn

#     vpc_config {
#         subnet_ids = var.public_subnets
#     }

#     tags = merge(var.common_tags, { Name = "${var.name}-eks-cluster" })
# }
# # --------------------------------------------------------------------------
# # EKS Node Group with public subnets
# resource "aws_eks_node_group" "public-node-group" {
#     cluster_name    = aws_eks_cluster.this.name
#     node_group_name = "${var.name}-public-node-group"
#     node_role_arn   = aws_iam_role.eks_node_group_role.arn
#     subnet_ids      = var.public_subnets

#     scaling_config {
#         desired_size = 2
#         max_size     = 3
#         min_size     = 1
#     }

#     tags = merge(var.common_tags, { Name = "${var.name}-public-node-group" })
# }

# # --------------------------------------------------------------------------
# # IAM Role for EKS Cluster
# resource "aws_iam_role" "eks_cluster_role" {
#     name = "${var.name}-eks-cluster-role"
#     assume_role_policy = jsonencode({
#         Version = "2012-10-17"
#         Statement = [{
#             Effect = "Allow"
#             Principal = {
#                 Service = "eks.amazonaws.com"
#             }
#             Action = "sts:AssumeRole"
#         }]
#     })
# }
# # Attach necessary policies to the EKS Cluster role
# resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
#     role       = aws_iam_role.eks_cluster_role.name
#     policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
# }
# # --------------------------------------------------------------------------
# # IAM Role for EKS Node Group
# resource "aws_iam_role" "eks_node_group_role" {
#     name = "${var.name}-eks-node-group-role"
#     assume_role_policy = jsonencode({
#         Version = "2012-10-17"
#         Statement = [{
#             Effect = "Allow"
#             Principal = {
#                 Service = "ec2.amazonaws.com"
#             }
#             Action = "sts:AssumeRole"
#         }]
#     })
# }
# # Attach necessary policies to the EKS Node Group role
# resource "aws_iam_role_policy_attachment" "eks_node_group_policy" {
#     role       = aws_iam_role.eks_node_group_role.name
#     policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
# }
# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#     role       = aws_iam_role.eks_node_group_role.name
#     policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
# }
# resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
#     role       = aws_iam_role.eks_node_group_role.name
#     policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# }
# # =+=+=+=+=+=+=+=+=+=+=+=+=+=+
# # next?