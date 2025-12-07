terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# 1. S3 Bucket and related resources (No changes here)
resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${var.suffix}-${var.project_name}-tfstatefile" # dev-caag-ps-nova-tfstatefile
  tags          = { Name = "${var.suffix}-${var.project_name}-tfstatefile" }
  acl = "private" # Ensures the bucket ACL is private
}
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}