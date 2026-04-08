# -------------------------------------------------------------------
# Instance Profile — wrapper to attach IAM role to EC2
# You cannot attach an IAM role directly to EC2, must use a profile
# -------------------------------------------------------------------
resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "${var.name}-bastion-instance-profile"
  role = aws_iam_role.bastion_ssm_role.name

  tags = merge(var.common_tags, { Name = "${var.name}-bastion-instance-profile" })
}


# -------------------------------------------------------------------
# Security Group for Bastion
# No inbound rules — SSM works by the agent calling OUT to AWS on 443
# -------------------------------------------------------------------
resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-bastion-sg"
  description = "Bastion host SG - no inbound needed, SSM uses outbound 443 only"
  vpc_id      = var.vpc_id
  ingress {
    description      = "Allow HTTP traffic from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Allow HTTP traffic from anywhere"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    description = "Allow outbound HTTPS to reach AWS SSM and EKS endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow Bastion to reach EKS Pods on 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Use your VPC CIDR to keep it internal
  }

  tags = merge(var.common_tags, { Name = "${var.name}-bastion-sg" })
}


# -------------------------------------------------------------------
# Bastion EC2 Instance
# -------------------------------------------------------------------
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

    tags = merge(var.common_tags, { Name = "${var.name}-bastion-volume" })
  }

  # user_data runs ONCE on first boot only.
  # If the instance already exists, taint it to force recreation:
  #   terraform taint module.bastion.aws_instance.bastion
  #   terraform apply
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update all packages
    dnf update -y

    # SSM Agent is pre-installed on AL2023 — just ensure it's running
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl

    # Configure kubeconfig for root — runs at boot so cluster must exist already
    # Cluster name and region are injected by Terraform templatestring
    aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
  EOF

  tags = merge(var.common_tags, {
    Name = "${var.name}-bastion-host"
    Role = "Bastion"
  })
}
