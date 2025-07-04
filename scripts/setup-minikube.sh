#!/bin/bash
# scripts/setup-minikube.sh - Comprehensive Minikube setup for Tractus-X

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${ENVIRONMENT:-development}"
CLUSTER_NAME="${CLUSTER_NAME:-tractus-x-${ENVIRONMENT}}"
DOMAIN_SUFFIX="${DOMAIN_SUFFIX:-minikube.local}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Required tools
    local required_tools=("docker" "kubectl" "helm" "minikube" "jq" "curl")
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites are met"
}

# Get resource configuration based on environment
get_resource_config() {
    case "$ENVIRONMENT" in
        development)
            echo "4 8192 40g"
            ;;
        staging)
            echo "6 12288 60g"
            ;;
        production)
            echo "8 16384 100g"
            ;;
        *)
            log_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Start Minikube cluster
start_minikube() {
    log_info "Starting Minikube cluster: $CLUSTER_NAME"
    
    # Get resource configuration
    read -r cpus memory disk_size <<< "$(get_resource_config)"
    
    # Check if cluster already exists
    if minikube profile list -o json 2>/dev/null | jq -r '.valid[].Name' | grep -q "^${CLUSTER_NAME}$"; then
        log_info "Cluster $CLUSTER_NAME already exists. Checking status..."
        
        # Start if stopped
        if ! minikube status -p "$CLUSTER_NAME" | grep -q "Running"; then
            log_info "Starting existing cluster..."
            minikube start -p "$CLUSTER_NAME"
        else
            log_info "Cluster is already running"
        fi
    else
        log_info "Creating new Minikube cluster with $cpus CPUs, ${memory}MB RAM, ${disk_size} disk"
        
        minikube start \
            --profile="$CLUSTER_NAME" \
            --cpus="$cpus" \
            --memory="$memory" \
            --disk-size="$disk_size" \
            --kubernetes-version=v1.24.0 \
            --driver=docker \
            --container-runtime=containerd \
            --feature-gates="GracefulNodeShutdown=true" \
            --addons=ingress,ingress-dns,storage-provisioner,default-storageclass,metrics-server \
            --wait=true
    fi
    
    # Set context
    minikube profile "$CLUSTER_NAME"
    kubectl config use-context "$CLUSTER_NAME"
    
    log_success "Minikube cluster is ready"
}

# Wait for Kubernetes to be ready
wait_for_kubernetes() {
    log_info "Waiting for Kubernetes to be ready..."
    
    # Wait for nodes to be ready
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Wait for system pods
    kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s
    
    # Wait for ingress controller
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
    
    log_success "Kubernetes is ready"
}

# Setup networking and DNS
setup_networking() {
    log_info "Setting up networking and DNS..."
    
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip -p "$CLUSTER_NAME")
    log_info "Minikube IP: $MINIKUBE_IP"
    
    # Setup /etc/hosts entries for local development
    if [ "$ENVIRONMENT" = "development" ]; then
        log_info "Setting up /etc/hosts entries..."
        
        # Backup existing hosts file
        sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
        
        # Remove existing Tractus-X entries
        sudo sed -i '/# Tractus-X Development Environment/,/^$/d' /etc/hosts
        
        # Add new entries
        cat << EOF | sudo tee -a /etc/hosts

# Tractus-X Development Environment - Managed by setup-minikube.sh
$MINIKUBE_IP argocd.$DOMAIN_SUFFIX
$MINIKUBE_IP portal.$DOMAIN_SUFFIX
$MINIKUBE_IP portal-backend.$DOMAIN_SUFFIX
$MINIKUBE_IP centralidp.$DOMAIN_SUFFIX
$MINIKUBE_IP dataconsumer-controlplane.$DOMAIN_SUFFIX
$MINIKUBE_IP dataconsumer-dataplane.$DOMAIN_SUFFIX
$MINIKUBE_IP dataprovider-controlplane.$DOMAIN_SUFFIX
$MINIKUBE_IP dataprovider-dataplane.$DOMAIN_SUFFIX
$MINIKUBE_IP edc-consumer.$DOMAIN_SUFFIX
$MINIKUBE_IP edc-consumer-dataplane.$DOMAIN_SUFFIX
$MINIKUBE_IP edc-provider.$DOMAIN_SUFFIX
$MINIKUBE_IP edc-provider-dataplane.$DOMAIN_SUFFIX
$MINIKUBE_IP vault.$DOMAIN_SUFFIX
$MINIKUBE_IP pgadmin.$DOMAIN_SUFFIX
$MINIKUBE_IP grafana.$DOMAIN_SUFFIX
$MINIKUBE_IP prometheus.$DOMAIN_SUFFIX
$MINIKUBE_IP alertmanager.$DOMAIN_SUFFIX
$MINIKUBE_IP loki.$DOMAIN_SUFFIX
$MINIKUBE_IP jaeger.$DOMAIN_SUFFIX
$MINIKUBE_IP bpdm-pool.$DOMAIN_SUFFIX
$MINIKUBE_IP bpdm-gate.$DOMAIN_SUFFIX
$MINIKUBE_IP dtr.$DOMAIN_SUFFIX

EOF
        
        log_success "DNS entries added to /etc/hosts"
    fi
}

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD..."
    
    # Create ArgoCD namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Install ArgoCD
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --version 5.46.7 \
        --values - << EOF
global:
  domain: argocd.$DOMAIN_SUFFIX

configs:
  params:
    server.insecure: $([ "$ENVIRONMENT" != "production" ] && echo "true" || echo "false")

server:
  service:
    type: ClusterIP
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.$DOMAIN_SUFFIX
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

controller:
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

repoServer:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
EOF
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    log_success "ArgoCD installed successfully"
    log_info "ArgoCD URL: https://argocd.$DOMAIN_SUFFIX"
    log_info "ArgoCD admin password: $ARGOCD_PASSWORD"
    
    # Save credentials to file
    cat > "$PROJECT_ROOT/argocd-credentials.txt" << EOF
ArgoCD Credentials
==================
URL: https://argocd.$DOMAIN_SUFFIX
Username: admin
Password: $ARGOCD_PASSWORD

Access via CLI:
argocd login argocd.$DOMAIN_SUFFIX --username admin --password $ARGOCD_PASSWORD --insecure
EOF
    
    log_info "ArgoCD credentials saved to: $PROJECT_ROOT/argocd-credentials.txt"
}

# Install Sealed Secrets Controller
install_sealed_secrets() {
    log_info "Installing Sealed Secrets Controller..."
    
    # Add Bitnami repository
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    # Install Sealed Secrets
    helm upgrade --install sealed-secrets bitnami/sealed-secrets \
        --namespace kube-system \
        --version 2.13.2 \
        --set fullnameOverride=sealed-secrets-controller
    
    # Wait for controller to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n kube-system
    
    log_success "Sealed Secrets Controller installed"
}

# Create storage class
create_storage_class() {
    log_info "Creating storage classes..."
    
    kubectl apply -f - << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  labels:
    environment: $ENVIRONMENT
    project: tractus-x
    managed-by: setup-script
provisioner: k8s.io/minikube-hostpath
parameters:
  type: pd-ssd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
    
    log_success "Storage classes created"
}

# Deploy ArgoCD applications
deploy_argocd_applications() {
    log_info "Deploying ArgoCD applications..."
    
    # Apply ArgoCD projects and applications
    kubectl apply -k "$PROJECT_ROOT/kubernetes/argocd/"
    
    log_success "ArgoCD applications deployed"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check cluster status
    kubectl cluster-info
    
    # Check namespaces
    kubectl get namespaces
    
    # Check ArgoCD
    kubectl get pods -n argocd
    
    # Check if Ingress is working
    curl -s -o /dev/null -w "%{http_code}" "http://argocd.$DOMAIN_SUFFIX" || log_warning "ArgoCD ingress may not be ready yet"
    
    log_success "Installation verification completed"
}

# Print access information
print_access_info() {
    log_info "Access Information"
    echo "===================="
    echo
    echo "Cluster: $CLUSTER_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Domain Suffix: $DOMAIN_SUFFIX"
    echo
    echo "ArgoCD:"
    echo "  URL: https://argocd.$DOMAIN_SUFFIX"
    echo "  Username: admin"
    echo "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Not available yet")"
    echo
    echo "Kubernetes:"
    echo "  Context: $CLUSTER_NAME"
    echo "  Dashboard: minikube dashboard -p $CLUSTER_NAME"
    echo
    echo "Monitoring (after applications are deployed):"
    echo "  Grafana: http://grafana.$DOMAIN_SUFFIX (admin/tractus-admin)"
    echo "  Prometheus: http://prometheus.$DOMAIN_SUFFIX"
    echo "  AlertManager: http://alertmanager.$DOMAIN_SUFFIX"
    echo "  Jaeger: http://jaeger.$DOMAIN_SUFFIX"
    echo
    echo "EDC Connectors:"
    echo "  Consumer CP: http://dataconsumer-controlplane.$DOMAIN_SUFFIX"
    echo "  Provider CP: http://dataprovider-controlplane.$DOMAIN_SUFFIX"
    echo "  Standalone Consumer: http://edc-consumer.$DOMAIN_SUFFIX"
    echo "  Standalone Provider: http://edc-provider.$DOMAIN_SUFFIX"
    echo
    echo "Support Services:"
    echo "  Vault: http://vault.$DOMAIN_SUFFIX"
    echo "  PgAdmin: http://pgadmin.$DOMAIN_SUFFIX (admin@tractus-x.org/tractus-admin)"
    echo
    echo "To access services, ensure /etc/hosts is configured or run:"
    echo "  minikube tunnel"
    echo
}

# Clean up function
cleanup() {
    log_warning "Cleaning up..."
    
    # Remove /etc/hosts entries
    if [ "$ENVIRONMENT" = "development" ]; then
        sudo sed -i '/# Tractus-X Development Environment/,/^$/d' /etc/hosts
        log_info "Removed /etc/hosts entries"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Main function
main() {
    log_info "Starting Tractus-X Minikube setup for environment: $ENVIRONMENT"
    
    check_prerequisites
    start_minikube
    wait_for_kubernetes
    setup_networking
    create_storage_class
    install_sealed_secrets
    install_argocd
    deploy_argocd_applications
    verify_installation
    print_access_info
    
    log_success "Tractus-X Minikube setup completed successfully!"
    log_info "You can now proceed to deploy applications using ArgoCD"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --cleanup      Clean up the environment"
        echo
        echo "Environment variables:"
        echo "  ENVIRONMENT    Target environment (development|staging|production)"
        echo "  CLUSTER_NAME   Minikube cluster name"
        echo "  DOMAIN_SUFFIX  Domain suffix for services"
        echo
        exit 0
        ;;
    --cleanup)
        log_info "Cleaning up Tractus-X environment..."
        
        # Delete Minikube cluster
        minikube delete -p "$CLUSTER_NAME" || true
        
        # Remove /etc/hosts entries
        cleanup
        
        # Remove credentials file
        rm -f "$PROJECT_ROOT/argocd-credentials.txt"
        
        log_success "Cleanup completed"
        exit 0
        ;;
    "")
        # No arguments, run main function
        main
        ;;
    *)
        log_error "Unknown argument: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac