# Configure AWS Providers
provider "aws" {
  region = var.aws_region
}


data "aws_route53_zone" "main" {
  name         = var.root_domain_name  # Your domain
  private_zone = false
}


# --- ACM Certificate for caag-ps-nova.caagagenticps.com ---
# This certificate MUST be in us-east-1 if it's going to be associated with a CloudFront distribution.
# Even if your main AWS resources are in another region, CloudFront requires ACM certs in us-east-1.
resource "aws_acm_certificate" "sonic_domain_cert" {
  domain_name       = "${var.sub_domain_name}.${var.root_domain_name}" 
  validation_method = "DNS"
  tags = {
    Name = "${var.sub_domain_name}.${var.root_domain_name}-cert"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# DNS records for ACM certificate validation
# Terraform automatically creates the necessary CNAME records in Route 53
# to validate the ownership of the domain for ACM.
resource "aws_route53_record" "sonic_domain_validation" {
  for_each = {
    for dvo in aws_acm_certificate.sonic_domain_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60 # Short TTL for quicker validation
}

# Wait for ACM certificate validation to complete
resource "aws_acm_certificate_validation" "sonic_domain_cert_validation" {
  certificate_arn         = aws_acm_certificate.sonic_domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.sonic_domain_validation : record.fqdn]
  # Ensure the CNAME record is created before validation attempts
  depends_on              = [aws_route53_record.sonic_domain_validation]
}


# --- Outputs ---
output "acm_certificate_arn" {
  description = "The ARN of the issued ACM certificate for caag-ps-nova.caagagenticps.com"
  value       = aws_acm_certificate.sonic_domain_cert.arn
}
