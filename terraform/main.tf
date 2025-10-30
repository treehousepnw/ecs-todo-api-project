provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ecs-todo-api"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "derek-ogletree"
    }
  }
}

# Get current AWS account info
data "aws_caller_identity" "current" {}

# Get ECR authorization token for Docker provider
data "aws_ecr_authorization_token" "token" {}

# Docker provider for building and pushing images
provider "docker" {
  registry_auth {
    address  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    username = "AWS"
    password = data.aws_ecr_authorization_token.token.password
  }
}

# VPC and Networking
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  health_check_path = "/health"
  certificate_arn   = var.certificate_arn # Optional for HTTPS
}

# RDS PostgreSQL Database
module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  db_name            = var.db_name
  db_username        = var.db_username
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage

  # Allow access from ECS tasks
  allowed_security_group_id = module.ecs.ecs_task_security_group_id
}

# ECS Cluster and Service
module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_target_group_arn  = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id

  # Container configuration
  container_image = var.container_image != "" ? var.container_image : "${module.ecs.ecr_repository_url}:latest"
  container_port  = 5000
  cpu             = var.ecs_task_cpu
  memory          = var.ecs_task_memory
  desired_count   = var.ecs_desired_count

  # Environment variables
  environment_vars = {
    ENVIRONMENT = var.environment
    APP_VERSION = var.app_version
    DB_HOST     = module.rds.db_address # Use db_address instead of db_endpoint
    DB_PORT     = "5432"
    DB_NAME     = var.db_name
    DB_USER     = var.db_username
  }

  # Secrets from Parameter Store
  secrets = {
    DB_PASSWORD = module.rds.db_password_parameter_arn
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", module.ecs.ecs_service_name, "ClusterName", module.ecs.ecs_cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.alb_arn_suffix],
            [".", "RequestCount", ".", "."],
            [".", "HealthyHostCount", "TargetGroup", module.alb.alb_arn_suffix, "LoadBalancer", module.alb.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.rds.db_instance_id],
            [".", "CPUUtilization", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
        }
      }
    ]
  })
}