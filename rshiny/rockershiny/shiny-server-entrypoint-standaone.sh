#!/bin/bash

# Enable debug mode to see executed commands
set -x

echo "🚀 Starting Shiny Server setup..."

# Load environment variables into R environment
echo "📋 Loading environment variables..."
echo AWS_CONTAINER_CREDENTIALS_RELATIVE_URI=$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI >> /home/shiny/.Renviron
echo AWS_EXECUTION_ENV=$AWS_EXECUTION_ENV >> /home/shiny/.Renviron
echo AWS_REGION=$AWS_REGION >> /home/shiny/.Renviron
echo ECS_AGENT_URI=$ECS_AGENT_URI >> /home/shiny/.Renviron
echo ECS_CONTAINER_METADATA_URI=$ECS_CONTAINER_METADATA_URI >> /home/shiny/.Renviron
echo ECS_CONTAINER_METADATA_URI_V4=$ECS_CONTAINER_METADATA_URI_V4 >> /home/shiny/.Renviron

# Wait for environment variables to propagate
echo "⏱ Waiting for environment variables to be available..."
sleep 5

# Validate if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed. Please install it before running this script."
    exit 1
fi

# Show AWS CLI version
echo "📦 AWS CLI Version:"
aws --version

# Validate if S3_BUCKET and S3_KEY are set
if [[ -z "$S3_BUCKET" || -z "$S3_KEY" ]]; then
    echo "❌ ERROR: S3_BUCKET and S3_KEY must be set as environment variables."
    env | grep S3_  # Debugging environment variables
    exit 1
fi

# Authenticate with Amazon ECR to ensure access
echo "🔐 Checking authentication with ECR..."
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin 456998814824.dkr.ecr.ap-southeast-2.amazonaws.com

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to authenticate with ECR."
    exit 1
else
    echo "✅ Successfully authenticated with ECR."
fi

# Attempt to download the application from S3
echo "📥 Downloading application from S3: s3://$S3_BUCKET/$S3_KEY"
aws s3 sync s3://$S3_BUCKET/$S3_KEY /srv/shiny-server/app

# Check if sync was successful
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to sync with S3."
    exit 1
fi

# List downloaded files for debugging
echo "📁 Downloaded files from S3:"
ls -la /srv/shiny-server/app/

# Set correct permissions
echo "🔒 Setting file permissions..."
chown -R shiny:shiny /srv/shiny-server/app
chmod -R 755 /srv/shiny-server/app

# Check internet connectivity
if [ $? -ne 0 ]; then
    echo "❌ ERROR: No Internet connectivity. Check VPC and NAT Gateway configuration."
else
    echo "✅ Internet connectivity is OK."
fi

# Validate if Shiny Server is installed
if [[ ! -f "/usr/bin/shiny-server" ]]; then
    echo "❌ ERROR: Shiny Server binary not found at /usr/bin/shiny-server."
    exit 1
fi

# Start Shiny Server
echo "🚀 Starting Shiny Server..."
/usr/bin/shiny-server &

# Keep the container running
while true; do sleep 3600; done
