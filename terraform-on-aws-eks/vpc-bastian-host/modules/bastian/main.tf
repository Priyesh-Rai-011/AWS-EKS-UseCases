# -------------------------------------------------------------------
# Data Source: latest Amazon Linux 2023 AMI
# SSM Agent comes pre-installed on Amazon Linux 2023
# so we don't need to install anything manually
# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
# IAM Role for Bastion
# -------------------------------------------------------------------
# Why do we need an IAM role for SSM?
# The EC2 instance needs permission to talk to AWS SSM service.
# Without this role, SSM agent on the instance has no credentials
# to register itself with AWS SSM — so you won't see it in the console.

resource "aws_iam_role" "bastion_ssm_role" {
  name = "${var.name}-bastion-ssm-role"

  # This is the trust policy — it says "EC2 service is allowed to assume this role"
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

# Attach the AWS managed policy that gives SSM full access to manage the instance
# AmazonSSMManagedInstanceCore allows:
#   - SSM agent to register with AWS
#   - You to start sessions via AWS Console or CLI
#   - SSM to send commands to the instance
resource "aws_iam_role_policy_attachment" "bastion_ssm_policy" {
  role       = aws_iam_role.bastion_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile is the "wrapper" that lets you attach an IAM role to an EC2 instance
# You can't attach an IAM role directly to EC2 — it must go through an instance profile
resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "${var.name}-bastion-instance-profile"
  role = aws_iam_role.bastion_ssm_role.name

  tags = merge(var.common_tags, { Name = "${var.name}-bastion-instance-profile" })
}

# -------------------------------------------------------------------
# Security Group for Bastion
# -------------------------------------------------------------------
# With SSM we do NOT need port 22 open at all.
# The instance only needs OUTBOUND port 443 to reach AWS SSM endpoints.
# No inbound rules needed — SSM works by the agent calling OUT to AWS.

resource "aws_security_group" "bastion_sg" {
  name        = "${var.name}-bastion-sg"
  description = "Bastion host SG - no inbound needed, SSM uses outbound 443 only"
  vpc_id      = var.vpc_id

  # NO ingress rules - SSM does not require any open inbound ports
  # This is what makes SSM more secure than SSH

  egress {
    description = "Allow outbound HTTPS to reach AWS SSM service endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name}-bastion-sg" })
}

# -------------------------------------------------------------------
# Bastion EC2 Instance
# -------------------------------------------------------------------
# Note: no key_name here — SSM login does not need a key pair
# Note: no Elastic IP needed — SSM connects through AWS internally

resource "aws_instance" "bastion" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id            # public subnet from vpc module
  iam_instance_profile = aws_iam_instance_profile.bastion_instance_profile.name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  # No key_name — we are using SSM, not SSH

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.common_tags, { Name = "${var.name}-bastion-volume" })
  }

  user_data = <<-EOF
    #!/bin/bash
    # Update all packages
    dnf update -y
    # SSM Agent is already installed on Amazon Linux 2023
    # Just make sure it's enabled and running
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF

  tags = merge(var.common_tags, {
    Name = "${var.name}-bastion-host"
    Role = "Bastion"
  })
}