#!/bin/bash
set -e

# Manual deployment script for building and pushing Docker image

ENV=${1:-dev}
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecs-todo-api-${ENV}"
IMAGE_TAG=${2:-latest}

echo "🚀 Deploying to ${ENV} environment..."
echo "   ECR Repository: ${ECR_REPO}"
echo "   Image Tag: ${IMAGE_TAG}"

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REPO}

# Build Docker image
echo "🔨 Building Docker image..."
cd app
docker build --platform linux/amd64 -t ecs-todo-api:${IMAGE_TAG} .

# Tag image
echo "🏷️  Tagging image..."
docker tag ecs-todo-api:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
docker tag ecs-todo-api:${IMAGE_TAG} ${ECR_REPO}:latest

# Push to ECR
echo "📤 Pushing to ECR..."
docker push ${ECR_REPO}:${IMAGE_TAG}
docker push ${ECR_REPO}:latest

# Update ECS service to use new image
echo "🔄 Updating ECS service..."
CLUSTER_NAME="ecs-todo-api-${ENV}-cluster"
SERVICE_NAME="ecs-todo-api-${ENV}-service"

aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --force-new-deployment \
    --region ${AWS_REGION} \
    > /dev/null

echo "✅ Deployment complete!"
echo "   Monitor deployment: aws ecs wait services-stable --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION}"