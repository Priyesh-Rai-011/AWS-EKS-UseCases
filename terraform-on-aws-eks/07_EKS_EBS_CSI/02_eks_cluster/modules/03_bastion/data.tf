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