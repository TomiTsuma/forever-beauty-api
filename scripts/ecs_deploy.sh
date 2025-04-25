#!/bin/bash

set -e
set -a 
source ../.env
set +a 

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecs describe-clusters --clusters ${ECS_CLUSTER_NAME} || aws ecs create-cluster --cluster-name ${ECS_CLUSTER_NAME}

aws iam get-role --role-name ecsTaskExecutionRole || \
    aws iam create-role \
        --role-name ecsTaskExecutionRole \
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

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

TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

aws logs describe-log-groups --log-group-name "/ecs/${ECS_TASK_FAMILY}" || \
    aws logs create-log-group --log-group-name "/ecs/${ECS_TASK_FAMILY}"

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=face-issue-detection-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text || \
    aws ec2 create-security-group \
        --group-name face-issue-detection-sg \
        --description "Security group for face issue detection service" \
        --query 'GroupId' \
        --output text)

aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port ${ECS_CONTAINER_PORT} \
    --cidr 0.0.0.0/0

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text)

SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[*].SubnetId' \
    --output text | tr '\t' ',')

aws ecs describe-services \
    --cluster ${ECS_CLUSTER_NAME} \
    --services ${ECS_SERVICE_NAME} || \
    aws ecs create-service \
        --cluster ${ECS_CLUSTER_NAME} \
        --service-name ${ECS_SERVICE_NAME} \
        --task-definition ${TASK_DEFINITION_ARN} \
        --desired-count ${ECS_DESIRED_COUNT} \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}"

aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --task-definition ${TASK_DEFINITION_ARN} \
    --desired-count ${DESIRED_COUNT}
 