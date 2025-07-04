#!/bin/bash
# scripts/cleanup.sh - Complete environment cleanup

set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-development}"
CLUSTER_NAME="${CLUSTER_NAME:-tractus-x-${ENVIRONMENT}}"

echo "🧹 Cleaning up Tractus-X environment..."
echo "Environment: $ENVIRONMENT"
echo "Cluster: $CLUSTER_NAME"

# Confirm deletion
read -p "Are you sure you want to delete the entire environment? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete ArgoCD applications
echo "Deleting ArgoCD applications..."
kubectl delete applications --all -n argocd || true

# Delete Helm releases
echo "Deleting Helm releases..."
helm uninstall --all-namespaces $(helm list --all-namespaces -q) || true

# Delete namespaces
echo "Deleting namespaces..."
kubectl delete namespace tractus-x edc-standalone monitoring argocd --ignore-not-found=true

# Delete Minikube cluster
echo "Deleting Minikube cluster..."
minikube delete --profile=$CLUSTER_NAME || true

# Clean up /etc/hosts entries
echo "Cleaning up /etc/hosts entries..."
sudo sed -i '/# Tractus-X Development Environment/,/^$/d' /etc/hosts || true

# Clean up local files
echo "Cleaning up local files..."
rm -f access-services.sh
rm -f argocd-credentials.txt
rm -f deployment-report-*.md

echo "✅ Cleanup completed!"