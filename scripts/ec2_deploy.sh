#!/bin/bash

set -a
source .env
set +a

UBUNTU_AMI=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text)

echo $UBUNTU_AMI


# Get default VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text)

# Get subnet ID from the default VPC
SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].SubnetId" \
    --output text)

# Create security group
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name forever-beauty-api-sg \
    --description "Security group for Forever Beauty API" \
    --vpc-id $VPC_ID \
    --query "GroupId" \
    --output text)

# Add inbound rules
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 8000 \
    --cidr 0.0.0.0/0

# Create EC2 instance
# Create IAM role
# aws iam create-role \
#     --role-name forever-beauty-ec2-role \
#     --assume-role-policy-document '{
#         "Version": "2012-10-17",
#         "Statement": [
#             {
#                 "Effect": "Allow",
#                 "Principal": {
#                     "Service": "ec2.amazonaws.com"
#                 },
#                 "Action": "sts:AssumeRole"
#             }
#         ]
#     }'

# Attach ECR policy to allow pulling images
aws iam attach-role-policy \
    --role-name forever-beauty-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Create instance profile and add role to it
# aws iam create-instance-profile \
#     --instance-profile-name forever-beauty-profile
# aws iam add-role-to-instance-profile \
#     --role-name forever-beauty-ec2-role \
#     --instance-profile-name forever-beauty-profile

# Export the profile name for use in EC2 creation
export IAM_INSTANCE_PROFILE="forever-beauty-profile"

aws ec2 create-key-pair --key-name forever-beauty --query 'KeyMaterial' --output text > forever-beauty.pem
chmod 400 forever-beauty.pem

echo "Deploying EC2 instance..."
aws ec2 run-instances \
    --image-id ami-0440d3b780d96b29d \
    --instance-type t2.micro \
    --key-name forever-beauty \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=forever-beauty-api}]" \
    --iam-instance-profile Name=$IAM_INSTANCE_PROFILE \
    --user-data "#!/bin/bash
                 sudo yum update -y
                 sudo yum install -y aws-cli
                 sudo yum install -y docker
                 mkdir ~/forever_beauty_api
                 "


echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
    --filters "Name=tag:Name,Values=forever-beauty-api"

INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=forever-beauty-api" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text)

echo "Allocating Elastic IP..."
ALLOCATION_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --query 'AllocationId' \
    --output text)

echo "Associating Elastic IP with instance..."
aws ec2 associate-address \
    --allocation-id $ALLOCATION_ID \
    --instance-id $INSTANCE_ID

export EC2_HOST=$(aws ec2 describe-addresses \
    --allocation-ids $ALLOCATION_ID \
    --query 'Addresses[0].PublicIp' \
    --output text)

echo "EC2 instance deployed at $EC2_HOST (Elastic IP)"


echo "Copying .env file to EC2..."
scp -i ./forever-beauty.pem .env ubuntu@$EC2_HOST:~/forever_beauty_api/


echo "Deploying to EC2..."
ssh -i ./forever-beauty.pem ubuntu@$EC2_HOST << 'EOF'
    sudo apt-get update -y
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo usermod -a -G docker ubuntu

    export $(grep -v '^#' ~/forever_beauty_api/.env | xargs)

    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    docker pull $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$DOCKER_IMAGE_TAG

    docker stop forever_beauty_api || true
    docker rm forever_beauty_api || true

    docker run -d \
        --name forever_beauty_api \
        --restart always \
        -p 8000:8000 \
        --env-file ~/forever_beauty_api/.env \
        $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$DOCKER_IMAGE_TAG
EOF

echo "Deployment completed!"