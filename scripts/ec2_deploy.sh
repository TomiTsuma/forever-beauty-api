#!/bin/bash

set -a
source .env
set +a

echo "Building Docker image..."
docker build -t $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG .

echo "Logging in to AWS ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "Tagging and pushing image to ECR..."
docker tag $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$DOCKER_IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$DOCKER_IMAGE_TAG

echo "Copying .env file to EC2..."
scp -i ~/.ssh/your-key.pem .env ec2-user@$EC2_HOST:~/forever_beauty_api/

echo "Deploying to EC2..."
ssh -i ~/.ssh/your-key.pem ec2-user@$EC2_HOST << 'EOF'
    # Update AWS CLI and install Docker if not present
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user

    # Login to ECR on EC2
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    # Pull latest image
    docker pull $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$DOCKER_IMAGE_TAG

    # Stop and remove existing container if it exists
    docker stop forever_beauty_api || true
    docker rm forever_beauty_api || true

    # Run new container
    docker run -d \
        --name forever_beauty_api \
        --restart always \
        -p 8000:8000 \
        --env-file ~/forever_beauty_api/.env \
        $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$DOCKER_IMAGE_TAG
EOF

echo "Deployment completed!"