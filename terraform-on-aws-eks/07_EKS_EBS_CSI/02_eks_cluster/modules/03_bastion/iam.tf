# -------------------------------------------------------------------
# IAM Role for Bastion
# -------------------------------------------------------------------
# The EC2 instance needs permission to talk to AWS SSM service.
# Without this role, SSM agent on the instance has no credentials
# to register itself with AWS SSM.

resource "aws_iam_role" "bastion_ssm_role" {
  name = "${var.name}-bastion-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, { Name = "${var.name}-bastion-ssm-role" })
}


# -------------------------------------------------------------------
# POLICY ATTACHMENT 1 — AWS Managed: SSM Core
# Allows SSM agent to register + allows you to start sessions
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "bastion_ssm_policy" {
  role       = aws_iam_role.bastion_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# -------------------------------------------------------------------
# POLICY 2 — Inline: EKS + EC2 Describe permissions
# aws_iam_role_policy writes permissions DIRECTLY into the role —
# no separate attachment needed. Both policies live on the same role.
# One role, one EC2 instance, multiple sets of permissions.
# -------------------------------------------------------------------
resource "aws_iam_role_policy" "bastion_eks_ec2_policy" {
  name = "${var.name}-eks-ec2-policy"
  role = aws_iam_role.bastion_ssm_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListAccessEntries",
          "ec2:DescribeInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",      
          "ec2:AuthorizeSecurityGroupIngress",
          "elasticloadbalancing:DescribeLoadBalancers",     
          "elasticloadbalancing:DescribeTargetGroups",      
          "elasticloadbalancing:DescribeListeners"          
        ]
        Resource = "*"
      }
    ]
  })
}