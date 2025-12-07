provider "aws" {
  region = var.aws_region
}

# --- ADD THIS: Data source to find the ACM certificate for your domain ---
# You must have already created a certificate in AWS Certificate Manager.
data "aws_acm_certificate" "main" {
  domain      = var.domain_name # This will be a new variable, e.g., "sonic.agentic.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "main" {
  name         = var.root_domain_name  # Your domain
  private_zone = false
}

#-------------------------------------------------
# NETWORKING (MODIFIED TO USE EXISTING VPC)
#-------------------------------------------------

# --- MODIFIED: Use a data source to get your existing VPC ---
data "aws_vpc" "existing" {
  id = var.existing_vpc_id
}

# Note: The resources for creating aws_subnet, aws_internet_gateway, aws_route_table,
# aws_eip, and aws_nat_gateway have been removed. You should provide the subnet IDs
# via variables.

#-------------------------------------------------
# SECURITY GROUP (UPDATED FOR EXISTING VPC)
#-------------------------------------------------

resource "aws_security_group" "ecs_service" {
  name        = "${var.prefix}-${var.project_name}-ecs-service-sg"
  description = "Allow inbound traffic from NLB to ECS service"
  # --- MODIFIED: Use the ID of the existing VPC ---
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description = "Allow traffic from NLB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # --- MODIFIED: Use the CIDR block of the existing VPC ---
    cidr_blocks = [data.aws_vpc.existing.cidr_block]
  }

  egress {
    description = "Allow outbound HTTPS to AWS services and internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-${var.project_name}-ecs-sg"
  }
}

#-------------------------------------------------
# IAM Roles and Policies (No changes in this section)
#-------------------------------------------------

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.prefix}-${var.project_name}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.prefix}-${var.project_name}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

  resource "aws_iam_policy" "ecs_task_policy" {
    name        = "${var.prefix}-${var.project_name}-ecs-task-policy"
    description = "Allows ECS Task to access Bedrock, DynamoDB, and Cognito"
  
    policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
       {
          Sid      = "BedrockAccess"
          Action   = "bedrock:InvokeModel*"
          Effect   = "Allow"
          Resource = [
              "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-sonic-v1:0",
            ]
        },
        {
            "Effect": "Allow",
            "Action": "bedrock:Retrieve",
            "Resource": "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/${var.bedrock_knowledge_base_id}"
        },
        {
          Sid      = "CognitoReadAccess"
          Action   = "cognito-idp:AdminGetUser"
          Effect   = "Allow"
          Resource = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
        }
      ]
    })
  }

data "aws_caller_identity" "current" {}


resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

resource "aws_cloudwatch_log_group" "ecs_backend" {
  name = "/ecs/${var.prefix}-${var.project_name}-backend" # A standard naming convention

  # Set how long you want to keep the logs. 7 days is a reasonable default.
  retention_in_days = 7

  tags = {
    Name = "${var.prefix}-${var.project_name}-backend-logs"
  }
}

#-------------------------------------------------
# ECS (UPDATED FOR EXISTING VPC)
#-------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-${var.project_name}-cluster"
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.prefix}-${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.prefix}-${var.project_name}-backend"
      image     = var.ecr_image_uri
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        {
          name  = "USER_POOL_ID"
          value = var.cognito_user_pool_id
        },
        {
          name  = "CLIENT_ID"
          value = var.cognito_user_pool_client_id
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  =  "KNOWLEDGE_BASE_ID"
          value =  var.bedrock_knowledge_base_id
        
        }
        
      ]
    }
  ])
}

resource "aws_ecs_service" "backend" {
  name            = "${var.prefix}-${var.project_name}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    # --- MODIFIED: Use the list of existing private subnet IDs ---
    subnets          = var.existing_private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "${var.prefix}-${var.project_name}-backend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.tls]
}

#-------------------------------------------------
# NLB (UPDATED FOR EXISTING VPC)
#-------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.prefix}-${var.project_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  # --- MODIFIED: Use the list of existing public subnet IDs ---
  subnets            = var.existing_public_subnet_ids

  tags = {
    Name = "${var.prefix}-${var.project_name}-nlb"
  }
}

resource "aws_lb_target_group" "main" {
  name        = "${var.prefix}-${var.project_name}-tg"
  port        = 80
  protocol    = "TCP"
  # --- MODIFIED: Use the ID of the existing VPC ---
  vpc_id      = data.aws_vpc.existing.id
  target_type = "ip"
  deregistration_delay = 600

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_listener" "tls" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "TLS"
  certificate_arn   = data.aws_acm_certificate.main.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

#-------------------------------------------------
# ROUTE 53 (No changes in this section)
#-------------------------------------------------
resource "aws_route53_record" "sonic_nlb_cname" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "CNAME"
  records = [aws_lb.main.dns_name]
  ttl     = 300
}