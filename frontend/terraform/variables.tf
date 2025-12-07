variable "aws_region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "nlb_dns_name" {
  description = "The DNS name of the backend Network Load Balancer."
  type        = string
  default     = "caag-ps-nova.caagagenticps.com"
}

variable "frontend_build_path" {
  description = "The relative path to the built frontend application files."
  type        = string
  # UPDATED: Changed from 'build' to 'dist' to match the Vite output
  default     = "../dist"
}

variable "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool."
  type        = string
  # Replace with your actual User Pool ID
  default     = "us-east-1_jw2QIRAs3" 
}

variable "cognito_user_pool_client_id" {
  description = "The Client ID of the Cognito User Pool App Client."
  type        = string
  # Replace with your actual Client ID
  default     = "335ut0nq05g3dnrnpdgpovej2i" 
}

# NEW: Variable for the custom Cognito domain
variable "cognito_domain_name" {
  description = "The custom domain for the Cognito User Pool."
  type        = string
  default     = "dev-caag-ps-nova-auth.auth.us-east-1.amazoncognito.com"
}

variable "acm_certificate_arn_id" {
  description = "ACM certificate arn."
  type        = string
  default     = "dbff1d96-79ca-4abd-81e4-96846b0ba071"
}

variable "suffix" {
  description = "The project name suffix."
  default     = "dev"
}

variable "project_name" {
  description = "The project name ."
  default     = "caag-ps-nova"
}
