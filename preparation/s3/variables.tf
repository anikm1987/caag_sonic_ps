variable "aws_region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "suffix" {
  description = "The project name suffix."
  default     = "dev"
}

variable "project_name" {
  description = "The project name ."
  default     = "caag-ps-nova"
}


variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-lock-table"
}

