Deployment Instructions
---------------------

## Table of Contents

1. [Terraform state using S3 bucket](#Terraform-state-using-S3-bucket)
2. [Network setup](#Network)
3. [Setup EC2 Instance](#Setup-EC2-Instance)
4. [EC2IAMPolicy](#EC2IAMPolicy)
5. [BedrockKnowledgeBase](#BedrockKnowledgeBase)
6. [Route53 domain](#Route53-domain)
7. [ACM Certificate](#ACM-Certificate)
8. [ECR](#ECR)
9. [Cognito](#Cognito)
10. [Frontend](#Frontend)
11. [Backend](#Backend)

## Terraform State using S3 bucket
- Create a S3 bucket to store all terraform state. Update below section with the S3 details to use.
`novasonicstatefile`
- Create a dynamodb table named `terraform-state-lock-table` and Partition key `LockID`. This will be used to terraform state lock files to avoid corruption.
- Terraform code should be stored under - ./caag_sonic_ps/preparation/s3/main.tf

## Network

- Create one VPC with 2 public and 2 private subnet
- internet gateway , nat gateway and associated route table entries.
- Terraform code is stored under [preparation/vpc/main.tf](preparation/vpc/main.tf)

## Setup EC2 Instance
1. Create an EC2 instance (LINUX) 
    - instance type: t2.large
    - Setup key pair
    - Select VPC
    - Region - us-east-1
    - Assign security group (ssh (22) enabled from your workstation)
    - Require internet connectivity
    - Storage: 50 GiB (gp3)
    - Add IAM instance profile (if already exist `my-ec2-role`) - can be added later. 

2. Install all required softwares (Note: below instructions are Ubuntu based, changed accordingly if you choose any other OS in Step - 1)
    - For detailed step , please refer to [preparation/ec2/initial_software.sh](preparation/ec2/initial_software.sh)


## EC2IAMPolicy
- Create a role by navigating to IAM - ec2-iam-role
- Add below permissions
    * AmazonCognitoPowerUser
    * AmazonEC2ContainerRegistryFullAccess
    * AmazonRoute53FullAccess
    * CloudFrontFullAccess
    * ElasticLoadBalancingFullAccess
- Create Customer inline policy as mentioned in [IAM Policy](preparation/iam_policy) 

`Note:` Attach the created role "ec2-iam-role" to the EC2 instance.


## BedrockKnowledgeBase

Amazon bedrock knowledgebase setup guide is available at [preparation/knowledgebase/KB_SETUP_GUIDE.md](preparation/knowledgebase/KB_SETUP_GUIDE.md)


## Route53 domain
- For registering new domain please follow the guideline mentioned in [Registering New Domain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure-section) 

- Example domain name : caagagenticps.com 

## ACM Certificate
- Prerequisties: Route53 domain is created and region of deployment is us-east-1
- To create the ACM certificate follow the below instructions 
- TF Location : [ACM Certs](preparation/acm_certs) 

```
# Navigate to the TF Location mentioned above
terraform init
terraform plan # check the plan and validate it is creating correct resources.
terraform apply 

# Capture the output - will be required in subsequent steps.
```

## ECR
- To create the ECR follow the below instructions 
- TF Location : [ECR](preparation/ecr) 

```
# Navigate to the TF Location mentioned above
terraform init
terraform plan # check the plan and validate it is creating correct resources.
terraform apply 

# Capture the output - will be required in subsequent steps.
```

## Cognito
- To create the Cognito instance follow the below instructions 
- TF Location : [Cognito](preparation/cognito) 

```
# Navigate to the TF Location mentioned above
terraform init
terraform plan # check the plan and validate it is creating correct resources.
terraform apply 

# Capture the output - will be required in subsequent steps.
```

## Frontend
- To create the Cognito instance follow the below instructions 
- TF Location : [Frontend](preparation/frontend) 

```
# Navigate to the frontend Location mentioned above
chmod +x *.sh
./deploy_ui.sh
# Capture the output - will be required in subsequent steps.
```

## Backend
- To create the Cognito instance follow the below instructions 
- TF Location : [Backend](preparation/backend) 

```
# Navigate to the Backened Location mentioned above
./docker_build_push.sh 1.0.0
cd terraform
terraform init
terraform plan # check the plan and validate it is creating correct resources.
terraform apply 

# Capture the output - will be required in subsequent steps.
```

