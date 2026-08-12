#!/usr/bin/env bash
set -euo pipefail

# Usage: ./up.sh <your-name>  e.g.  ./up.sh alex
NAME="${1:-}"

if [[ -z "$NAME" ]]; then
  echo "Usage: ./up.sh <your-name>  (e.g. ./up.sh alex)"
  exit 1
fi


REGION="$(aws configure get region)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}/infrastructure"

echo ">> Initialising Terraform..."
terraform init -input=false

echo ">> Validating Terraform scripts..."
terraform fmt
terraform validate

echo ">> Building your EKS cluster. This takes ~15 minutes — go get a coffee."
terraform apply -auto-approve -var="developer_name=${NAME}"

echo ">> Connecting kubectl to your cluster..."
CLUSTER_NAME="$(terraform output -raw cluster_name)"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo ">> Done! Your nodes:"
kubectl get nodes

echo ">> Creating staging and production namespaces..."
kubectl create namespace taskly-staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace taskly-production --dry-run=client -o yaml | kubectl apply -f -

cd "${SCRIPT_DIR}"

export CLUSTER_NAME
export ACCOUNT_ID
export AWS_REGION="${REGION}"
export SCRIPT_DIR
export REPO_ROOT

echo ">> Installing ArgoCD..."
chmod u+x install-argocd.sh
./install-argocd.sh

echo ">> Installing Prometheus + Grafana..."
chmod u+x install-monitoring.sh
./install-monitoring.sh

echo ">> Installing NGINX ingress..."
chmod u+x install-nginx-ingress.sh
./install-nginx-ingress.sh

echo ">> Installing external DNS..."
chmod u+x install-external-dns.sh
./install-external-dns.sh