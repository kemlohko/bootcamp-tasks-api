#!/usr/bin/env bash
# Installs external-dns with the IRSA role.
# Watches Ingress and HTTPRoute resources and auto-creates DNS records in Route53.
set -euo pipefail

NAMESPACE="external-dns"
EXTDNS_ROLE_ARN="$(terraform -chdir="${REPO_ROOT}/infrastructure" output -raw external_dns_role_arn)"

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update external-dns

helm upgrade --install external-dns external-dns/external-dns \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set provider.name=aws \
  --set "env[0].name=AWS_DEFAULT_REGION" \
  --set "env[0].value=${AWS_REGION}" \
  --set "sources[0]=ingress" \
  --set "sources[1]=service" \
  --set "domainFilters[0]=ironlabs.online" \
  --set policy=sync \
  --set registry=txt \
  --set txtOwnerId=eks-alex \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${EXTDNS_ROLE_ARN}" \
  --wait --timeout=5m

echo ""
echo "==> external-dns installed."
kubectl get pods -n "${NAMESPACE}"
