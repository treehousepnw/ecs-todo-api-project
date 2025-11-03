terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # Backend configuration - will be initialized with terraform init
  # Run: terraform init -backend-config="bucket=YOUR_BUCKET_NAME" -backend-config="key=ecs-todo-api-project/terraform.tfstate"
  backend "s3" {
    # bucket         = "WILL_BE_PROVIDED_VIA_CLI"
    # key            = "WILL_BE_PROVIDED_VIA_CLI"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}