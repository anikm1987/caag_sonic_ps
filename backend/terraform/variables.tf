variable "domain_name" {
  description = "The fully qualified domain name for the API endpoint."
  type        = string
  default     = "caag-ps-nova.caagagenticps.com"
}

variable "aws_region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "ecr_image_uri" {
  description = "The URI of the Docker image in ECR."
  # Replace with your ECR image URI from the previous step
  default     = "012599249602.dkr.ecr.us-east-1.amazonaws.com/caag-ps-nova-backend:1.0.0"
}

variable "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool for authentication."
  type        = string
  default     = "us-east-1_jw2QIRAs3"
}

variable "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client."
  type        = string
  default     = "335ut0nq05g3dnrnpdgpovej2i"
}

variable "prefix" {
  description = "The project name suffix."
  default     = "dev"
}

variable "root_domain_name" {
  description = "The root domain managed in Route 53 (e.g., accentureagentic.com)."
  type        = string
  default     = "caagagenticps.com"
}

variable "project_name" {
  description = "The project name ."
  default     = "caag-ps-nova"
}


variable "bedrock_knowledge_base_id" {
  description = "Bedrock knowledge base id"
  type        = string
  default     = "RFK08LQLSL"
}


# variables.tf

variable "existing_vpc_id" {
  description = "The ID of the existing VPC where resources will be deployed."
  type        = string
  default     = "vpc-08954b4e266fc3ea3"
}

variable "existing_public_subnet_ids" {
  description = "A list of at least two existing public subnet IDs for the Network Load Balancer."
  type        = list(string)
  default     = ["subnet-0ea9058183a3dab4d", "subnet-06d376615a9226d73"]
}

variable "existing_private_subnet_ids" {
  description = "A list of at least two existing private subnet IDs for the ECS Fargate tasks."
  type        = list(string)
  default     = ["subnet-00b758cafcd37f9a6", "subnet-0a1cfffc7afa67250"]
}
