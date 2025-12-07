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

locals {
  mime_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    gif  = "image/gif"
    svg  = "image/svg+xml"
    ico  = "image/vnd.microsoft.icon"
    txt  = "text/plain"
  }

  # DEFINITIVE: The exact <script> block content to be injected
  app_config_script_content = <<-EOT
    <script>
      window.APP_CONFIG = {
        appUrl: "https://${aws_cloudfront_distribution.frontend.domain_name}",
        cognitoUserPoolId: "${var.cognito_user_pool_id}",
        cognitoAppClientId: "${var.cognito_user_pool_client_id}",
        cognitoDomain: "https://${var.cognito_domain_name}",
        backendEndpoint: "wss://${var.nlb_dns_name}"
      };
    </script>
  EOT
}

# 1. S3 Bucket and related resources (No changes here)
resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${var.suffix}-${var.project_name}-frontend-"
  tags          = { Name = "${var.suffix}-${var.project_name}-frontend-bucket" }
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



# 2. CloudFront and related resources (No changes here)
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }
  # NEW: Add NLB as a custom origin for your API/WebSocket traffic
  origin {
    domain_name = var.nlb_dns_name # Use the variable for the NLB's DNS name
    origin_id   = "NLB-Origin-${var.project_name}-${var.suffix}"      # Give it a meaningful, unique ID
    # CloudFront will connect to your NLB's TLS listener on port 443
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only" # CloudFront will connect to NLB over HTTPS
      # Ensure these match or are compatible with your NLB's ssl_policy ("ELBSecurityPolicy-TLS13-1-2-2021-06")
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }
  # NEW: Ordered cache behavior for API/WebSocket traffic
  ordered_cache_behavior {
    path_pattern     = "/api/*" # Adjust this pattern to match your API/WebSocket paths
    target_origin_id = "NLB-Origin-${var.project_name}-${var.suffix}" # Point to the new NLB origin using its ID
    viewer_protocol_policy = "redirect-to-https"

    # CRITICAL for WebSockets and dynamic APIs: Forward all necessary headers, query strings, and cookies
    forwarded_values {
      headers = [
        "Host",
        "Authorization", # If your API uses Authorization headers
        # Add any other custom headers your backend ECS service expects
      ]
      query_string = true # Forward all query parameters
      cookies {
        forward = "all" # Forward all cookies if your API uses them
      }
    }
    # Disable caching for dynamic API responses and WebSockets
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    # Ensure methods required for API/WebSockets are allowed
    allowed_methods = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"] # Only cache GET/HEAD
  }
  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
  viewer_certificate {
    cloudfront_default_certificate = false # Crucial: Must be false for custom cert
    acm_certificate_arn            = "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/${var.acm_certificate_arn_id}"
    ssl_support_method             = "sni-only" 
    minimum_protocol_version       = "TLSv1.2_2021" 
  }
  tags = { Name = "${var.suffix}-${var.project_name}-frontend-dist" }
}
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.suffix}-oac-${aws_s3_bucket.frontend.id}"
  description                       = "OAC for the ${var.project_name} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
# --- MERGED S3 Bucket Policy: CloudFront access + HTTPS Enforcement ---
resource "aws_s3_bucket_policy" "frontend" { # Keep this existing resource name
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "cloudfront.amazonaws.com" },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend.arn}/*",
        Condition = {
          StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn }
        }
      },
      {
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*", 
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*",
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false" 
          }
        }
      }
    ]
  })
  # The depends_on is not strictly necessary here because bucket policy inherently depends on bucket existence
  # and the public_access_block. However, keeping it doesn't hurt.
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}
# 3. Use the templatefile function to render the final index.html content
locals {
  rendered_index_html = templatefile("${var.frontend_build_path}/index.html", {
    app_config_script = local.app_config_script_content
  })
}

# 4. Upload all built frontend files EXCEPT the original index.html
resource "aws_s3_object" "frontend_files" {
  for_each = setsubtract(fileset(var.frontend_build_path, "**/*"), ["index.html"])

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${var.frontend_build_path}/${each.value}"
  content_type = lookup(local.mime_types, regex("\\.([^\\.]+)$", each.value)[0], "application/octet-stream")
  etag         = filemd5("${var.frontend_build_path}/${each.value}")
}

# 5. SOLELY manage the dynamic, rendered index.html here.
resource "aws_s3_object" "index_file" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  content_type = "text/html"
  content      = local.rendered_index_html
  etag         = md5(local.rendered_index_html)
}
