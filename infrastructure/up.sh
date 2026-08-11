#!/usr/bin/env bash
set -euo pipefail

# Usage: ./up.sh <your-name> <environment>   e.g.  ./up.sh richard staging
NAME="${1:-}"
ENVIRONMENT="${2:-}"

if [[ -z "$NAME" || -z "$ENVIRONMENT" ]]; then
  echo "Usage: ./up.sh <your-name> <environment>  (e.g. ./up.sh richard staging)"
  exit 1
fi

VALID_ENVIRONMENTS=("staging" "production")
if [[ ! " ${VALID_ENVIRONMENTS[*]} " =~ " ${ENVIRONMENT} " ]]; then
  echo "Error: '${ENVIRONMENT}' is not a valid environment."
  echo "Valid options: ${VALID_ENVIRONMENTS[*]}"
  exit 1
fi

REGION="${AWS_REGION:-us-east-1}"

cd environments/"${ENVIRONMENT}"

echo ">> Initialising Terraform..."
terraform init -input=false

echo ">> Validating Terraform scripts..."
terraform fmt
terraform validate

echo ">> Building your EKS cluster. This takes ~15 minutes — go get a coffee."
terraform apply -var="developer_name=${NAME}"

echo ">> Connecting kubectl to your cluster..."
aws eks update-kubeconfig --name "eks-taskly-${NAME}-${ENVIRONMENT}" --region "${REGION}"

echo ">> Done! Your nodes:"
kubectl get nodes

# connect_command = "aws eks update-kubeconfig --name eks-taskly-alex-staging --region us-east-1"
#eks_cluster_name = "eks-taskly-alex-staging"
#rds_endpoint = "taskly-alex-staging.c8dksii68r5i.us-east-1.rds.amazonaws.com:5432"
#redis_endpoint = "taskly-alex-staging.dj3ys1.0001.use1.cache.amazonaws.com"