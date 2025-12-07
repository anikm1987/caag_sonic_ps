output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution for the frontend."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_url" {
  description = "The fully-qualified URL for the frontend application."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
