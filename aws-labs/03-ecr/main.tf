locals {
  repo_tags = merge(var.tags, { Name = var.repo_name })
}

resource "aws_ecr_repository" "this" {
  name                 = var.repo_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration { scan_on_push = true }

  dynamic "encryption_configuration" {
    for_each = var.enable_kms_encryption ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = var.kms_key_arn
    }
  }

  # Default AES256 when KMS not enabled
  dynamic "encryption_configuration" {
    for_each = var.enable_kms_encryption ? [] : [1]
    content {
      encryption_type = "AES256"
    }
  }

  tags = local.repo_tags
}

# Lifecycle policy: protect 'staging' tag from expiration, then keep only last N images overall
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Never expire images tagged 'staging' (high threshold)",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["staging"],
          countType     = "imageCountMoreThan",
          countNumber   = 999999
        },
        action = { type = "expire" }
      },
      {
        rulePriority = 2,
        description  = "Keep only the last N images (any tag)",
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = var.lifecycle_keep_last
        },
        action = { type = "expire" }
      }
    ]
  })
}

# Optional: Pull-through cache for Docker Hub or other upstream registry
resource "aws_ecr_pull_through_cache_rule" "upstream" {
  count                 = var.enable_pull_through_cache ? 1 : 0
  ecr_repository_prefix = var.ecr_cache_prefix
  upstream_registry_url = var.upstream_registry_url
  depends_on            = [aws_ecr_repository.this]
}
