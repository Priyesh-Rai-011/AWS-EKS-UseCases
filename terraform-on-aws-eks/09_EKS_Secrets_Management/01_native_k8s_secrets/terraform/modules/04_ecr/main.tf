# ==============================================================================
# ECR REPOSITORY
# Stores container images for workloads deployed in the EKS cluster.
# Lifecycle policy keeps the last 10 tagged images — older ones are auto-deleted.
# ==============================================================================
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # Scans each pushed image for known CVEs automatically
  }

  tags = merge(var.common_tags, { Name = var.repository_name })
}

# ── Lifecycle policy — keep only the last 10 images ──────────────────────────
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images, expire the rest"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
