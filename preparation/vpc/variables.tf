variable "aws_region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}
variable "prefix" {
  description = "The project name suffix."
  default     = "dev"
}
variable "project_name" {
  description = "The project name ."
  default     = "caag-ps-nova"
}
variable "cidr_block" {
  description = "The CIDR block for the VPC."
  default     = "10.3.0.0/16"
}