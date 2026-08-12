#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="monitoring"

echo ">> Adding Prometheus community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo ">> Creating ${NAMESPACE} namespace..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait

echo ""
echo ">> Done. Checking pods..."
kubectl get pods -n "${NAMESPACE}"

echo ""
echo ">> To access Grafana:"
echo "   kubectl port-forward svc/monitoring-grafana -n ${NAMESPACE} 3000:80"
echo "   Open http://localhost:3000  (username: admin, password: admin)"
echo ""
echo ">> To access Prometheus:"
echo "   kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n ${NAMESPACE} 9090:9090"
echo "   Open http://localhost:9090"