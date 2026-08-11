#!/usr/bin/env bash
set -euo pipefail

# Usage: ./down.sh <your-name> <environment>   e.g.  ./down.sh richard staging
NAME="${1:-}"
ENVIRONMENT="${2:-}"

if [[ -z "$NAME" || -z "$ENVIRONMENT" ]]; then
  echo "Usage: ./down.sh <your-name> <environment>   (e.g. ./down.sh richard staging)"
  exit 1
fi

VALID_ENVIRONMENTS=("staging" "production")
if [[ ! " ${VALID_ENVIRONMENTS[*]} " =~ " ${ENVIRONMENT} " ]]; then
  echo "Error: '${ENVIRONMENT}' is not a valid environment."
  echo "Valid options: ${VALID_ENVIRONMENTS[*]}"
  exit 1
fi

cd environments/"${ENVIRONMENT}"

# IMPORTANT: Kubernetes "LoadBalancer" services create AWS load balancers that
# Terraform doesn't know about. If you leave them, "terraform destroy" gets stuck
# trying to delete the network. So we delete them first.
echo ">> Removing any LoadBalancer services (Terraform can't see these)..."
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  for svc in $(kubectl get svc -n "$ns" \
        -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{" "}{end}' 2>/dev/null); do
    echo "   deleting service '$svc' in namespace '$ns'"
    kubectl delete svc "$svc" -n "$ns" || true
  done
done
sleep 20   # give AWS a moment to actually delete the load balancers

echo ">> Destroying all cluster infrastructure..."
terraform destroy -auto-approve -var="developer_name=${NAME}"

echo ">> Done. Everything is gone. Your bill for this cluster is now \$0."