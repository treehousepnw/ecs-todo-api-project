# Production Environment Configuration
environment = "prod"
ACCOUNT_ID  = "your-account-id"

# Container image (will be updated by CI/CD)
container_image = "ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/ecs-todo-api-prod:latest"

# ECS Configuration
ecs_task_cpu      = 512
ecs_task_memory   = 1024
ecs_desired_count = 2

# Database Configuration
db_instance_class    = "db.t4g.small"
db_allocated_storage = 50