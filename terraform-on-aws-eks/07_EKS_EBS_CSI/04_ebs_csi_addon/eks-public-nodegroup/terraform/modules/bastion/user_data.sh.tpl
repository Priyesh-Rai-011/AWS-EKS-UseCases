#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# System update
# ---------------------------------------------------------------------------
dnf update -y

# ---------------------------------------------------------------------------
# Ensure amazon-ssm-agent is running
# ---------------------------------------------------------------------------
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# ---------------------------------------------------------------------------
# Install kubectl (latest stable for Kubernetes 1.33)
# ---------------------------------------------------------------------------
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

# ---------------------------------------------------------------------------
# Configure kubectl for the EKS cluster
# ---------------------------------------------------------------------------
mkdir -p /home/ssm-user/.kube
aws eks update-kubeconfig \
  --region "${aws_region}" \
  --name   "${cluster_name}" \
  --kubeconfig /home/ssm-user/.kube/config

# ---------------------------------------------------------------------------
# Clone the EKS use-cases repository
# ---------------------------------------------------------------------------
dnf install -y git
git clone https://github.com/Priyesh-Rai-011/AWS-EKS-UseCases.git /home/ssm-user/eks-repo
chown -R ssm-user:ssm-user /home/ssm-user/eks-repo
chown -R ssm-user:ssm-user /home/ssm-user/.kube
