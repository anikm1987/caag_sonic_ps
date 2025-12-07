# --- Variables ---
variable "aws_region" {
  description = "The AWS region where the NLB and ACM certificate are located."
  type        = string
  default     = "us-east-1"
}

variable "root_domain_name" {
  description = "The root domain managed in Route 53 (e.g., caagagenticps.com)."
  type        = string
  default     = "caagagenticps.com"
}

variable "sub_domain_name" {
  description = "The subdomain for the NLB (e.g., sonic)."
  type        = string
  default     = "caag-ps-nova"
}
