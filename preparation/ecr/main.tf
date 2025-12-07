# Configure AWS Provider (ensure this matches your desired region)
provider "aws" {
  region = var.aws_region
}

# --- Variables ---
variable "aws_region" {
  description = "The AWS region where the ECR repository will be created."
  type        = string
  default     = "us-east-1" # Or your desired region
}

variable "ecr_repository_name" {
  description = "The name for your ECR repository."
  type        = string
  default     = "caag-ps-nova-backend" # <-- Customize this name
}

# --- ECR Repository ---
resource "aws_ecr_repository" "main_repo" {
  name = var.ecr_repository_name

  # Optional: Enable image scanning on push (recommended for security)
  image_scanning_configuration {
    scan_on_push = true
  }

  # Optional: Configure image tag immutability (recommended to prevent accidental overwrites)
  # Once an image is pushed with a tag, that tag cannot be overwritten.
  image_tag_mutability = "IMMUTABLE" # "MUTABLE" is the default

  tags = {
    Name        = var.ecr_repository_name
    Environment = "Development"
    Service     = "ContainerImage"
  }
}

# Optional: ECR Repository Policy
# This policy grants permissions for pushing and pulling images to/from the repository.
# You might want to restrict this to specific IAM roles/users or only allow certain accounts.
resource "aws_ecr_repository_policy" "main_repo_policy" {
  repository = aws_ecr_repository.main_repo.name

  policy = jsonencode({
    Version = "2008-10-17",
    Statement = [
      {
        Sid    = "AllowPushPull",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" # Allows root user (or anyone with sufficient permissions in this account)
          # Or more specifically for an ECS Task Execution Role:
          # AWS = "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/your-ecs-task-execution-role-name"
        },
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
      },
    ]
  })
}

# Optional: ECR Lifecycle Policy (to manage old images)
# This example deletes images older than 7 days, keeping at least 1 image.
# Adjust as per your retention requirements.
resource "aws_ecr_lifecycle_policy" "main_repo_lifecycle_policy" {
  repository = aws_ecr_repository.main_repo.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire images older than 7 days",
        selection    = {
          tagStatus   = "untagged", # Apply to untagged images
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 7
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "Keep at least 1 image", # This rule ensures at least 1 image is kept even if tagged.
        selection    = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = 1
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}


# --- Data Source for Current Account ID ---
# Needed for the ECR Repository Policy ARN construction
data "aws_caller_identity" "current" {}

# --- Outputs ---
output "ecr_repository_name" {
  description = "The name of the ECR repository."
  value       = aws_ecr_repository.main_repo.name
}

output "ecr_repository_url" {
  description = "The full URI of the ECR repository."
  value       = aws_ecr_repository.main_repo.repository_url
}

output "ecr_repository_arn" {
  description = "The ARN of the ECR repository."
  value       = aws_ecr_repository.main_repo.arn
}