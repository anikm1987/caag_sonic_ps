# --- Variables ---
variable "aws_region" {
  description = "The AWS region where the Cognito User Pool will be deployed."
  type        = string
  default     = "us-east-1" # Or your desired region, e.g., "eu-west-1"
}

variable "project_name" {
  description = "A name prefix for your resources."
  type        = string
  default     = "caag-ps-nova"
}

variable "cloudfront_app_callback_urls" {
  description = "A list of callback URLs for your CloudFront application (e.g., https://your.cloudfront.app.com/oauth2/idpresponse)."
  type        = list(string)
  # IMPORTANT: Replace with your actual CloudFront application URLs
  default = [
    "https://dn68kqn3j59j8.cloudfront.net",
    "http://localhost:8080/callback" # For local development/testing
  ]
}

variable "cloudfront_app_logout_urls" {
  description = "A list of logout URLs for your CloudFront application."
  type        = list(string)
  # IMPORTANT: Replace with your actual CloudFront application URLs
  default = [
    "https://dn68kqn3j59j8.cloudfront.net",
    "http://localhost:8080/logout" # For local development/testing
  ]
}

variable "prefix" {
  description = "The environment name prefix."
  default     = "dev"
}