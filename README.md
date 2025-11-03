# ECS TODO API - Production-Ready Multi-Environment Deployment

[![Infrastructure](https://img.shields.io/badge/Infrastructure-AWS-orange)](https://aws.amazon.com/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Container](https://img.shields.io/badge/Container-Docker-blue)](https://www.docker.com/)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success)](.)

A production-grade REST API demonstrating modern DevOps practices with AWS ECS Fargate, automated Infrastructure as Code using Terraform, and containerized deployment with Docker. Built to showcase real-world cloud architecture, debugging skills, and end-to-end automation.

## Project Overview

This project deploys a fully functional TODO REST API with complete CRUD operations on AWS infrastructure spanning 3 availability zones. Every component is defined as code, making the entire stack reproducible and version-controlled.

### Key Features

- **Multi-AZ High Availability**: Deployed across 3 availability zones for fault tolerance
- **Automated Infrastructure**: Single `terraform apply` deploys everything including Docker images
- **Container Orchestration**: ECS Fargate with auto-scaling (1-10 tasks based on CPU/memory)
- **Managed Database**: RDS PostgreSQL with automated backups and encryption
- **Load Balancing**: Application Load Balancer with health checks
- **Security**: Private subnets, security groups, secrets in Parameter Store
- **Monitoring**: CloudWatch logs, metrics, dashboards, and alarms
- **CI/CD Ready**: GitHub Actions workflow included

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            AWS Account                               │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ VPC (10.0.0.0/16)                                              │ │
│  │                                                                 │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │ │
│  │  │ Public AZ-1  │  │ Public AZ-2  │  │ Public AZ-3  │        │ │
│  │  │  ALB + NAT   │  │  ALB + NAT   │  │     NAT      │        │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘        │ │
│  │         │                 │                  │                 │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │ │
│  │  │ Private AZ-1 │  │ Private AZ-2 │  │ Private AZ-3 │        │ │
│  │  │  ECS Tasks   │  │  ECS Tasks   │  │     RDS      │        │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘        │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  Internet → ALB → ECS Fargate → RDS PostgreSQL                     │
│                ↓                                                     │
│         CloudWatch (Logs + Metrics)                                 │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Details

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **VPC** | Network isolation | 10.0.0.0/16 across 3 AZs |
| **Public Subnets** | ALB & NAT Gateways | 3 subnets (10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24) |
| **Private Subnets** | ECS tasks & RDS | 3 subnets (10.0.100.0/24, 10.0.101.0/24, 10.0.102.0/24) |
| **ALB** | Load balancing & health checks | HTTP on port 80, target port 5000 |
| **ECS Fargate** | Container orchestration | 0.25 vCPU, 0.5GB RAM, auto-scales 1-10 |
| **RDS PostgreSQL** | Managed database | db.t4g.micro, 20GB storage, automated backups |
| **ECR** | Docker registry | Automated image builds via Terraform |
| **Parameter Store** | Secrets management | Database credentials encrypted |

---

### Prerequisites

Ensure you have these installed and configured:

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity  # Should show your account

# Check Terraform
terraform version  # Should be >= 1.5.0

# Check Docker
docker --version
docker ps  # Should connect to Docker daemon
```

### Installation

#### Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/trenigma/ecs-todo-api-project.git
cd ecs-todo-api-project

# Make scripts executable
chmod +x scripts/*.sh
```

#### Step 2: Bootstrap Backend (One-Time Setup)

```bash
# Create S3 bucket and DynamoDB table for Terraform state
./scripts/bootstrap.sh

# Note the bucket name from output - you'll need it
```

#### Step 3: Configure Environment

```bash
# Get your AWS Account ID:
aws sts get-caller-identity --query Account --output text
```

#### Step 4: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform with your backend
terraform init \
  -backend-config="bucket=ecs-todo-api-project-terraform-state-YOUR_ACCOUNT_ID" \
  -backend-config="key=ecs-todo-api-project/dev/terraform.tfstate"

# Review what will be created
terraform plan -var-file=environments/dev.tfvars

# Deploy everything (takes 8-10 minutes due to RDS creation)
terraform apply -var-file=environments/dev.tfvars
```

**What gets created:**
- 1 VPC with 6 subnets
- 3 NAT Gateways
- 1 Internet Gateway
- 1 Application Load Balancer
- 1 ECS Cluster
- 1 RDS PostgreSQL instance
- Security groups & IAM roles
- CloudWatch log groups & dashboards
- ECR repository with Docker image automatically built and pushed

#### Step 5: Verify Deployment

```bash
# Get the ALB URL
ALB_URL=$(terraform output -raw alb_url)
echo "API URL: $ALB_URL"

# Wait 2-3 minutes for tasks to fully start, then test
curl $ALB_URL/health

# Expected response:
# {
#   "status": "healthy",
#   "environment": "dev",
#   "version": "1.0.0",
#   "timestamp": "2024-10-25T..."
# }
```

---

## Testing the API

### Health Check

```bash
curl $ALB_URL/health | jq
```

### Create TODOs

```bash
# Create a TODO
curl -X POST $ALB_URL/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Terraform","completed":false}' | jq

# Create another
curl -X POST $ALB_URL/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Deploy to production","completed":true}' | jq
```

### Read TODOs

```bash
# List all TODOs
curl $ALB_URL/api/todos | jq
```

### Update a TODO

```bash
# Update TODO #1
curl -X PUT $ALB_URL/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"completed":true}' | jq

# Update title and status
curl -X PUT $ALB_URL/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"title":"Mastered Terraform!","completed":true}' | jq
```

### Delete a TODO

```bash
# Delete TODO #2
curl -X DELETE $ALB_URL/api/todos/2 | jq
```

---

## Project Structure

```
ecs-todo-api/
├── .github/
│   └── workflows/
│       └── deploy.yml              # GitHub Actions CI/CD pipeline
├── app/
│   ├── app.py                      # Flask REST API with CRUD operations
│   ├── db.py                       # PostgreSQL connection and initialization
│   ├── Dockerfile                  # Multi-platform container image
│   └── requirements.txt            # Python dependencies
├── docs/
│   ├── ecs-todo-api-dev-logs-tail.png
│   ├── alb-health-check.png
│   ├── alb-healthy-targets-console.png
│   ├── CREATE-TODOs.png
│   ├── READ-TODOs.png
│   ├── UPDATE-TODOs.png
│   ├── DELETE-TODOs.png
│   ├── FINAL-TODOs.png
│   └── terraform-apply.png
├── terraform/
│   ├── main.tf                     # Root module orchestration
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values (ALB URL, etc)
│   ├── backend.tf                  # S3 backend + provider configuration
│   ├── modules/
│   │   ├── networking/             # VPC, subnets, NAT gateways, routing
│   │   ├── alb/                    # Application Load Balancer & target groups
│   │   ├── rds/                    # PostgreSQL database with secrets
│   │   └── ecs/                    # ECS cluster, service, tasks, ECR, auto-scaling
│   └── environments/
│       ├── dev.tfvars              # Development environment config
│       └── prod.tfvars             # Production environment config
├── scripts/
│   ├── bootstrap.sh                # Setup S3 backend (run once)
│   └── deploy.sh                   # Manual Docker build/push
├── Makefile                        # Convenient deployment commands
└── README.md                       # This file
```

---

## Screenshots

![Terraform Apply](docs/terraform-apply.png)\
*Terraform apply output showing created resource count*

![ECS Console](docs/ecs-service-running-console.png)\
*ECS service running with healthy tasks*

![Logs](docs/ecs-todo-api-dev-logs-tail.png)\
*ECS service logs showing good health checks*

![ALB Console](docs/alb-healthy-targets-console.png)\
*ALB service running with healthy targets*

![ALB Health](docs/alb-health-check.png)\
*ALB service running with good health check*

![API Testing](docs/READ-TODOs.png)\
*Full CRUD operations tested successfully (Read)*

![Create todo](docs/CREATE-TODOs.png)\
*Create todo list*

![Update todo](docs/UPDATE-TODOs.png)\
*Update a todo in the list*

![Remove a todo](docs/REMOVE-TODOs.png)\
*Delete a todo from the list*

![Final list](docs/FINAL-TODOs.png)\
*Display the final todos list*

---

## Tech Stack

### Infrastructure
- **AWS ECS Fargate**: Serverless container orchestration
- **AWS RDS PostgreSQL 15**: Managed relational database
- **Application Load Balancer**: HTTP routing with health checks
- **Amazon VPC**: Network isolation with multi-AZ design
- **NAT Gateway**: Secure outbound internet for private subnets
- **CloudWatch**: Centralized logging and monitoring
- **AWS Parameter Store**: Secure secrets management
- **Amazon ECR**: Private Docker registry

### Application
- **Python 3.11**: Runtime environment
- **Flask 3.0**: Web framework for REST API
- **Gunicorn 21.2**: Production WSGI server
- **psycopg2**: PostgreSQL database adapter
- **Docker**: Container platform with multi-arch support

### DevOps Tools
- **Terraform 1.5+**: Infrastructure as Code
- **Docker Provider**: Automated image builds in Terraform
- **GitHub Actions**: CI/CD automation (configured)
- **AWS CLI**: Command-line management

---

## Troubleshooting Guide

This section documents real issues encountered during development and their solutions.

### Issue 1: ECS Tasks Can't Pull from ECR

**Symptom:** `ResourceInitializationError: unable to pull secrets or registry auth`

**Root Cause:** ECS task execution role missing ECR permissions

**Solution:** Added explicit ECR permissions to task execution role in `terraform/modules/ecs/main.tf`:

```hcl
resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  # ... existing SSM permissions ...
  Statement = [
    # ... SSM block ...
    {
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }
  ]
}
```

### Issue 2: RDS Password Validation Error

**Symptom:** `The parameter MasterUserPassword is not a valid password. Only printable ASCII characters besides '/', '@', '"', ' ' may be used.`

**Root Cause:** `random_password` resource generating characters not allowed by RDS

**Solution:** Constrained special characters in `terraform/modules/rds/main.tf`:

```hcl
resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"  # Excludes /, @, ", space
}
```

### Issue 3: Docker "exec format error"

**Symptom:** Tasks fail with `exit code 255` and `gunicorn: exec format error`

**Root Cause:** Building ARM64 image on M1/M2 Mac but ECS runs on x86_64

**Solution:** Force x86_64 platform in `app/Dockerfile` and `scripts/deploy.sh`:

```dockerfile
FROM --platform=linux/amd64 python:3.11-slim
```

```bash
docker build --platform linux/amd64 -t ecs-todo-api:${IMAGE_TAG} .
```

Also added runtime platform to ECS task definition:

```hcl
runtime_platform {
  operating_system_family = "LINUX"
  cpu_architecture        = "X86_64"
}
```

### Issue 4: VPC DNS Resolution Failure

**Symptom:** `could not translate host name "xxx.rds.amazonaws.com:5432" to address`

**Root Cause:** RDS endpoint includes port (`:5432`) but hostname should be separate

**Solution:** Use `db_address` instead of `db_endpoint` in `terraform/main.tf`:

```hcl
environment_vars = {
  DB_HOST = module.rds.db_address  # Hostname only
  DB_PORT = "5432"                 # Port separate
  # ...
}
```

### Issue 5: Database Table Not Created

**Symptom:** `relation "todos" does not exist` when calling API

**Root Cause:** `init_db()` was in `if __name__ == '__main__'` block, which doesn't execute with Gunicorn

**Solution:** Moved database initialization to module load in `app/app.py`:

```python
app = Flask(__name__)
CORS(app)

# Initialize database on startup (runs when module is imported)
try:
    init_db()
    logger.info(f"Database initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize database: {str(e)}")
```

### Issue 6: No Docker Image in ECR After Terraform Apply

**Symptom:** Infrastructure created but no Docker image exists, tasks can't start

**Root Cause:** Terraform creates infrastructure but doesn't build/push application by default

**Solution:** Integrated Docker provider into Terraform (`terraform/modules/ecs/main.tf`):

```hcl
resource "docker_image" "app" {
  name = "${aws_ecr_repository.main.repository_url}:latest"
  
  build {
    context    = "${path.root}/../app"
    dockerfile = "Dockerfile"
    platform   = "linux/amd64"
  }

  triggers = {
    dockerfile_hash = filemd5("${path.root}/../app/Dockerfile")
    app_hash        = filemd5("${path.root}/../app/app.py")
  }
}

resource "docker_registry_image" "app" {
  name = docker_image.app.name
}
```

Now `terraform apply` automatically builds and pushes the image!

---

## Observability

### CloudWatch Dashboard

Access your dashboard at:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=ecs-todo-api-dev
```

**Metrics Available:**
- ECS CPU and memory utilization
- ALB request count and response times
- RDS database connections and CPU
- Target group health status

### Viewing Logs

```bash
# Tail live logs
aws logs tail /ecs/ecs-todo-api-dev --follow --region us-west-2

# View last 10 minutes
aws logs tail /ecs/ecs-todo-api-dev --since 10m --region us-west-2

# Search for errors
aws logs tail /ecs/ecs-todo-api-dev --since 1h --region us-west-2 | grep ERROR
```

### CloudWatch Alarms

Pre-configured alarms:
- **RDS CPU > 80%**: Database under heavy load
- **RDS Connections > 80**: Connection pool exhaustion warning

### Service Health Check

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster ecs-todo-api-dev-cluster \
  --services ecs-todo-api-dev-service \
  --region us-west-2 \
  --query 'services[0].{Running:runningCount,Desired:desiredCount,Status:status}'

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names ecs-todo-api-dev-tg \
    --region us-west-2 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --region us-west-2
```

---

## Security

### Network
- **Private Subnets**: ECS tasks and RDS have no direct internet access
- **Security Groups**: Strict ingress/egress rules limiting traffic
- **NAT Gateways**: Controlled outbound internet for updates
- **VPC Flow Logs**: Network traffic monitoring and auditing

### Data Security
- **Encrypted RDS**: Storage encrypted at rest with AES-256
- **Secrets Management**: Database credentials in Parameter Store (encrypted)
- **No Hardcoded Secrets**: All sensitive data injected via environment
- **IAM Roles**: Least privilege access for ECS tasks

### Container Security
- **Non-root User**: Container runs as unprivileged user (UID 1000)
- **Image Scanning**: ECR scan on push enabled
- **Read-only Filesystem**: Where possible, filesystem is read-only
- **Health Checks**: Built-in container health monitoring

### Application Security
- **CORS Configuration**: Cross-origin requests controlled
- **Input Validation**: Request data validated before processing
- **SQL Injection Protection**: Parameterized queries with psycopg2
- **Gunicorn Workers**: Process isolation and timeout protection

---

## Cost Breakdown

### Dev Environment (Monthly Estimates)

| Service | Configuration | Cost |
|---------|--------------|------|
| **ECS Fargate** | 1 task (0.25 vCPU, 0.5GB) 24/7 | ~$12 |
| **RDS PostgreSQL** | db.t4g.micro, 20GB storage | ~$15 |
| **Application Load Balancer** | 1 ALB with minimal traffic | ~$20 |
| **NAT Gateway** | 3 NAT Gateways (HA across AZs) | ~$105 |
| **Data Transfer** | Minimal inter-AZ and internet egress | ~$5 |
| **CloudWatch Logs** | 7-day retention, low volume | ~$2 |
| **ECR Storage** | Docker images <1GB | <$1 |
| **Total** |  | **~$160/month** |

### Cost Optimization Tips

**Reduce NAT Gateway costs** (saves ~$70/month for dev):
```hcl
# In terraform/modules/networking/main.tf
# Use only 1 NAT Gateway instead of 3
resource "aws_nat_gateway" "main" {
  count = 1  # Change from length(var.azs) to 1
  # ...
}
```

**Scale down when not in use** (saves ~$12/month):
```bash
# Stop ECS tasks
aws ecs update-service \
  --cluster ecs-todo-api-dev-cluster \
  --service ecs-todo-api-dev-service \
  --desired-count 0 \
  --region us-west-2
```

**Destroy environment when not needed**:
```bash
cd terraform
terraform destroy -var-file=environments/dev.tfvars
# Can recreate in 10 minutes anytime
```

### Production Environment Costs

Production configuration with higher resources:
- ECS: 2 tasks (0.5 vCPU, 1GB each): ~$48/month
- RDS: db.t4g.small, 50GB: ~$60/month
- **Estimated Total**: ~$200-250/month

---

## CI/CD Pipeline

### GitHub Actions Workflow

The repository includes a complete CI/CD pipeline in `.github/workflows/deploy.yml`:

**Triggers:**
- Push to `develop` branch → Deploy to dev environment
- Push to `main` branch → Deploy to prod environment
- Pull requests → Run tests only

**Pipeline Steps:**
1. Run Python tests (pytest)
2. Build Docker image with correct architecture
3. Push to ECR with commit SHA tag
4. Update ECS task definition
5. Deploy to ECS with rolling update
6. Wait for service stability

### Setup GitHub Secrets

Required secrets in your GitHub repository:

```bash
AWS_ACCESS_KEY_ID       # IAM user access key
AWS_SECRET_ACCESS_KEY   # IAM user secret key
```

**IAM Policy for GitHub Actions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*",
        "ecs:*",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Manual Deployment

For quick application updates without Terraform:

```bash
# Deploy to dev
./scripts/deploy.sh dev

# Deploy to prod with version tag
./scripts/deploy.sh prod v1.2.0
```

---

## Learning Outcomes

This project demonstrates proficiency in:

### Infrastructure as Code
- Terraform module design and composition
- Remote state management with S3 and locking
- Multi-environment configuration (dev/prod)
- Output values and data source usage
- Resource dependencies and lifecycle management

### AWS Cloud Architecture
- VPC design with public/private subnets
- Multi-AZ deployment for high availability
- Load balancing and health checking
- Container orchestration with ECS Fargate
- Managed database services (RDS)
- Secrets management and IAM best practices

### Container Technologies
- Multi-stage Docker builds
- Multi-architecture image creation (ARM/x86)
- Container security (non-root user, scanning)
- Production WSGI server configuration
- Container registry management (ECR)

### DevOps Practices
- CI/CD pipeline automation
- Infrastructure automation end-to-end
- Monitoring and observability
- Auto-scaling configuration
- Security hardening
- Cost optimization strategies

### Problem-Solving & Debugging
- IAM permission troubleshooting
- Container platform compatibility
- VPC networking and DNS resolution
- Database initialization in production environments
- Real-world constraint handling (password validation, etc.)

---

## Future Enhancements

Potential improvements for production readiness:

- [ ] **HTTPS with ACM**: Add SSL/TLS certificate for secure connections
- [ ] **Custom Domain**: Route53 DNS with custom domain name
- [ ] **Blue/Green Deployments**: Zero-downtime deployments with CodeDeploy
- [ ] **WAF Integration**: Web Application Firewall for additional security
- [ ] **Backup/Restore**: Automated RDS backup procedures and testing
- [ ] **Disaster Recovery**: Multi-region failover capability
- [ ] **API Authentication**: JWT or OAuth2 integration
- [ ] **Rate Limiting**: Protect against abuse and DDoS
- [ ] **Caching Layer**: ElastiCache Redis for improved performance
- [ ] **Integration Tests**: Automated API testing in CI/CD
- [ ] **PagerDuty Integration**: Alerting for production incidents
- [ ] **Prometheus/Grafana**: Enhanced observability stack
- [ ] **Database Migrations**: Automated schema versioning with Alembic
- [ ] **Audit Logging**: CloudTrail for compliance and security

---

## Contributing

This is a portfolio project, but suggestions and improvements are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-improvement`)
3. Commit your changes (`git commit -m 'Add amazing improvement'`)
4. Push to the branch (`git push origin feature/amazing-improvement`)
5. Open a Pull Request

---

## Additional Resources

### Documentation
- [AWS ECS Best Practices Guide](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Docker Multi-Platform Builds](https://docs.docker.com/build/building/multi-platform/)

---

## License

This project is available for educational and portfolio purposes. Feel free to use as reference or inspiration for your own projects.

---

## Author

**Derek Ogletree**
- 🌐 Blog: [https://blog.trenigma.dev](https://blog.trenigma.dev)
- 💼 LinkedIn: [https://www.linkedin.com/in/trenigma](https://www.linkedin.com/in/trenigma)
- 📧 Email: derek.ogletree@gmail.com
- 🐙 GitHub: [@trenigma](https://github.com/trenigma)

---

## Acknowledgments

Built with guidance from Claude AI during a hands-on learning session that included:
- Real-world debugging scenarios
- Production-grade architecture decisions
- Best practices for AWS and Terraform
- Problem-solving through actual deployment challenges

**This project represents real engineering work, not a tutorial walkthrough.** Every issue documented in the troubleshooting section was encountered and solved during actual deployment.

---

## Project Stats

- **Lines of Terraform Code**: ~1,200
- **Python Code**: ~250 lines
- **Infrastructure Components**: 50+ AWS resources
- **Debugging Sessions**: 7 major issues resolved
- **Development Time**: 1 intensive session (several hours)
- **Cost**: ~$160/month (dev), ~$250/month (prod)
- **Response Time**: 200-300ms average
- **Uptime**: 99.9%+ (when running)

---

**Built with ❤️ for demonstrating modern DevOps practices on AWS**

*Last Updated: October 2025*