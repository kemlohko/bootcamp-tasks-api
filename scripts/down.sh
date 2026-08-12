#!/usr/bin/env bash
set -euo pipefail

# Usage: ./down.sh <your-name>  e.g.  ./down.sh alex
NAME="${1:-}"

if [[ -z "$NAME" ]]; then
  echo "Usage: ./down.sh <your-name>  (e.g. ./down.sh alex)"
  exit 1
fi

CLUSTER_NAME="$(terraform output -raw cluster_name)"
REGION="${aws configure get region}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}/infrastructure"

echo ">> Connecting kubectl to the cluster being destroyed (${CLUSTER_NAME})..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo ">> Removing any LoadBalancer services (Terraform can't see these)..."
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  for svc in $(kubectl get svc -n "$ns" \
        -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{" "}{end}' 2>/dev/null); do
    echo "   deleting service '$svc' in namespace '$ns'"
    kubectl delete svc "$svc" -n "$ns" || true
  done
done
sleep 20

echo ">> Removing Kubernetes-managed resources first (while cluster access is still valid)..."
terraform destroy -auto-approve -var="developer_name=${NAME}" \
  -target=kubernetes_secret_v1.taskly_db_staging \
  -target=kubernetes_secret_v1.taskly_db_production \
  -target=kubernetes_service_account_v1.taskly_app || true

echo ">> Destroying remaining infrastructure..."
terraform destroy -auto-approve -var="developer_name=${NAME}"

echo ">> Done. Everything is gone. Your bill for this cluster is now \$0."