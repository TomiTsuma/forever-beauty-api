#!/bin/bash

set -e
set -a 
source .env
set +a 

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} ||  aws ecr create-repository --repository-name ${ECR_REPOSITORY}

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

docker build -t ${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG} .

docker tag ${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG}

docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG}

echo "ECR Repository URI: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}" 