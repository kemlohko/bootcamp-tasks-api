#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="monitoring"

echo ">> Adding Grafana Helm repo..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo ">> Installing Loki..."
helm upgrade --install loki grafana/loki \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set loki.useTestSchema=true \
  --set singleBinary.replicas=1 \
  --set singleBinary.persistence.enabled=false \
  --set "singleBinary.extraVolumes[0].name=storage" \
  --set "singleBinary.extraVolumes[0].emptyDir.sizeLimit=5Gi" \
  --set "singleBinary.extraVolumeMounts[0].name=storage" \
  --set "singleBinary.extraVolumeMounts[0].mountPath=/var/loki" \
  --set chunksCache.enabled=false \
  --set resultsCache.enabled=false \
  --set backend.replicas=0 \
  --set read.replicas=0 \
  --set write.replicas=0 \
  --wait

echo ">> Installing Promtail (ships container logs to Loki)..."
helm upgrade --install promtail grafana/promtail \
  --namespace "${NAMESPACE}" \
  --set "config.clients[0].url=http://loki-gateway.${NAMESPACE}.svc.cluster.local/loki/api/v1/push" \
  --wait

echo ""
echo ">> Done. Checking pods..."
kubectl get pods -n "${NAMESPACE}" | grep -E "loki|promtail"