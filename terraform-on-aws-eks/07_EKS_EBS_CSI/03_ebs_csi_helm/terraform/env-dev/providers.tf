provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { ManagedBy = "Terraform" }
  }
}

# Helm + Kubernetes providers use exec to get a fresh token each run.
# aws eks get-token resolves at apply time after the cluster exists.
provider "helm" {
  kubernetes {
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region]
    }
  }
}

provider "kubernetes" {
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.aws_region]
  }
}
