data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "bastion_ssm_role" {
  name = "${var.name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, { Name = "${var.name}-ssm-role" })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_policy" {
  role       = aws_iam_role.bastion_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "bastion_eks_ec2_policy" {
  name = "${var.name}-eks-ec2-policy"
  role = aws_iam_role.bastion_ssm_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:ListAccessEntries",
        "ec2:DescribeInstances",
        "ec2:DescribeSubnets",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.bastion_ssm_role.name

  tags = merge(var.common_tags, { Name = "${var.name}-instance-profile" })
}

resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-sg"
  description = "Bastion SG - no inbound rules; SSM uses outbound 443 only"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow HTTPS outbound to AWS SSM and EKS endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name}-sg" })
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.bastion_instance_profile.name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.common_tags, { Name = "${var.name}-volume" })
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    dnf update -y

    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl

    # Configure kubeconfig
    aws eks update-kubeconfig \
      --region ${var.aws_region} \
      --name ${var.cluster_name}

    # Clone repo so manifests are available on the bastion
    git clone https://github.com/Priyesh-Rai-011/AWS-EKS-UseCases.git /home/ssm-user/eks-repo
    chown -R ssm-user:ssm-user /home/ssm-user/eks-repo
  EOF

  tags = merge(var.common_tags, {
    Name = "${var.name}-host"
    Role = "Bastion"
  })
}
