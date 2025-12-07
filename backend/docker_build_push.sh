#!/bin/bash
# Accept tag as input, default to 1.0.0 if not provided
TAG=${1:-1.0.0}

echo "Using tag: $TAG"

# Build the Docker image with the provided tag
docker build --no-cache -t caag-ps-nova-backend:$TAG .

# Tag the image for ECR
docker tag caag-ps-nova-backend:$TAG 012599249602.dkr.ecr.us-east-1.amazonaws.com/caag-ps-nova-backend:$TAG

# Authenticate Docker to AWS ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 012599249602.dkr.ecr.us-east-1.amazonaws.com

# Push the Docker image to ECR
docker push 012599249602.dkr.ecr.us-east-1.amazonaws.com/caag-ps-nova-backend:$TAG
