#!/bin/bash
set -e

# Bootstrap script to create S3 bucket and DynamoDB table for Terraform state

PROJECT_NAME="ecs-todo-api"
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="${PROJECT_NAME}-terraform-state-${AWS_ACCOUNT_ID}"

echo "🚀 Bootstrapping Terraform backend..."
echo "   Region: ${AWS_REGION}"
echo "   Bucket: ${BUCKET_NAME}"

# Create S3 bucket for Terraform state
echo "📦 Creating S3 bucket..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    
    echo "✅ S3 bucket created"
else
    echo "ℹ️  S3 bucket already exists"
fi

# Enable versioning
echo "🔄 Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

# Enable encryption
echo "🔒 Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Block public access
echo "🛡️  Blocking public access..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
echo "🔐 Creating DynamoDB table for state locking..."
if ! aws dynamodb describe-table --table-name terraform-state-lock --region "${AWS_REGION}" &>/dev/null; then
    aws dynamodb create-table \
        --table-name terraform-state-lock \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"
    
    echo "✅ DynamoDB table created"
else
    echo "ℹ️  DynamoDB table already exists"
fi

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Update terraform/environments/*.tfvars with your AWS account ID"
echo "   2. Run: cd terraform"
echo "   3. Run: terraform init -backend-config=\"bucket=${BUCKET_NAME}\" -backend-config=\"key=ecs-todo-api/dev/terraform.tfstate\""
echo "   4. Run: terraform plan -var-file=environments/dev.tfvars"
echo ""
echo "💾 Backend config:"
echo "   Bucket: ${BUCKET_NAME}"
echo "   Region: ${AWS_REGION}"
echo "   DynamoDB Table: terraform-state-lock"