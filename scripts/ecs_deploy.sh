#!/bin/bash

set -e
set -a 
source ../.env
set +a 

echo "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Creating or verifying ECS cluster ${ECS_CLUSTER_NAME}..."
# aws ecs describe-clusters --clusters ${ECS_CLUSTER_NAME} || aws ecs create-cluster --cluster-name ${ECS_CLUSTER_NAME}
aws ecs create-cluster --cluster-name ${ECS_CLUSTER_NAME} 

echo "Creating or verifying ECS Task Execution Role..."
aws iam get-role --role-name ecsTaskExecutionRole || \
    aws iam create-role \
        --role-name ecsTaskExecutionRole \
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

echo "Attaching ECS Task Execution Role policy..."
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

echo "Generating task definition JSON..."
cat > task-definition.json << EOF
{
    "family": "${ECS_TASK_FAMILY}",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "${ECS_CPU}",
    "memory": "${ECS_MEMORY}",
    "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "${ECS_CONTAINER_NAME}",
            "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/face-issue-detection:latest",
            "portMappings": [
                {
                    "containerPort": ${ECS_CONTAINER_PORT},
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "OPENAI_API_KEY",
                    "value": "${OPENAI_API_KEY}"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/${ECS_TASK_FAMILY}",
                    "awslogs-region": "${AWS_REGION}",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF

echo "Registering task definition..."
TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "Creating or verifying CloudWatch log group... ${ECS_TASK_FAMILY}..."
aws logs describe-log-groups --log-group-name-pattern "${ECS_TASK_FAMILY}" || \
    aws logs create-log-group --log-group-name-pattern "${ECS_TASK_FAMILY}"

echo "Creating or retrieving security group..."
SECURITY_GROUP_ID=$(
    aws ec2 create-security-group \
        --group-name face-issue-detection-sg \
        --description "Security group for face issue detection service" \
        --query 'GroupId' \
        --output text)

echo "Configuring security group ingress rules..."
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port ${ECS_CONTAINER_PORT} \
    --cidr 0.0.0.0/0

echo "Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text)

echo "Getting subnet information..."
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].SubnetId' \
    --output text | tr '\t' ',')

echo "Creating or updating ECS service..."

aws ecs create-service \
    --cluster ${ECS_CLUSTER_NAME} \
    --service-name ${ECS_SERVICE_NAME} \
    --task-definition ${TASK_DEFINITION_ARN} \
    --desired-count ${ECS_DESIRED_COUNT} \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}"

echo "Updating ECS service with new task definition..."
aws ecs update-service \
    --cluster ${ECS_CLUSTER_NAME} \
    --service ${ECS_SERVICE_NAME} \
    --task-definition ${TASK_DEFINITION_ARN} \
    --desired-count ${ECS_DESIRED_COUNT}

echo "Deployment completed successfully!"