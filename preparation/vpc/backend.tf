terraform {
  backend "s3" {
    bucket         = "dev-caag-ps-nova-tfstatefile"
    # A unique path for this project's state file within the S3 bucket.
    # Use a clear naming convention, e.g., <environment>/<service-name>/terraform.tfstate
    key            = "dev/nova-ps/vpc/terraform.tfstate" # <-- Customize this path and filename
    # !! IMPORTANT: The region where your S3 bucket is located !!
    region         = "us-east-1"
    encrypt        = true # Ensures state is encrypted at rest in S3
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
#      version = "~> 5.0" # Specify your desired AWS provider version
    }
  }
}


