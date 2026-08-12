#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"

echo ">> Creating argocd namespace..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing ArgoCD..."
kubectl apply -n "${NAMESPACE}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts

echo ">> Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo ">> Applying Application manifests..."
kubectl apply -f "${REPO_ROOT}/argocd/staging-app.yaml"
kubectl apply -f "${REPO_ROOT}/argocd/production-app.yaml"

echo ">> Fetching initial admin password..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo ">> Done. ArgoCD is installed."
echo ">> Username: admin"
echo ">> Password: ${ADMIN_PASSWORD}"
echo ""
echo ">> To access the UI, run:"
echo "   kubectl port-forward svc/argocd-server -n "${NAMESPACE}" 8080:443"
echo ">> Then open https://localhost:8080"