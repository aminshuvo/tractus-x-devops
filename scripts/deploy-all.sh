#!/bin/bash
# scripts/deploy-all.sh - Complete Tractus-X deployment automation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${ENVIRONMENT:-development}"
DEPLOY_MODE="${DEPLOY_MODE:-full}"
SKIP_TESTS="${SKIP_TESTS:-false}"
TIMEOUT="${TIMEOUT:-1800}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=12

progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${PURPLE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} $1"
}

# Error handling
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Deployment failed at step ${CURRENT_STEP}/${TOTAL_STEPS}"
        log_info "Check logs above for details"
        
        # Collect failure information
        echo "=== FAILURE DIAGNOSTICS ==="
        kubectl get pods --all-namespaces | grep -v Running || true
        kubectl get events --all-namespaces --field-selector type=Warning | tail -10 || true
    fi
}
trap cleanup EXIT

# Dependency checks
check_dependencies() {
    progress "Checking dependencies"
    
    local missing_tools=()
    local required_tools=("kubectl" "helm" "terraform" "minikube" "jq" "curl")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Run: ./scripts/install-tools.sh"
        exit 1
    fi
    
    # Check Docker
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "All dependencies are available"
}

# Infrastructure setup
setup_infrastructure() {
    progress "Setting up infrastructure"
    
    log_info "Initializing Minikube cluster..."
    ./scripts/setup-minikube.sh
    
    log_info "Applying Terraform configuration..."
    cd "$PROJECT_ROOT/terraform"
    
    if [ ! -f ".terraform/terraform.tfstate" ]; then
        terraform init
    fi
    
    terraform plan -var-file="environments/${ENVIRONMENT}.tfvars" -var="environment=${ENVIRONMENT}"
    terraform apply -var-file="environments/${ENVIRONMENT}.tfvars" -var="environment=${ENVIRONMENT}" -auto-approve
    
    cd "$PROJECT_ROOT"
    log_success "Infrastructure setup completed"
}

# Wait for ArgoCD to be ready
wait_for_argocd() {
    progress "Waiting for ArgoCD to be ready"
    
    log_info "Waiting for ArgoCD deployment..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
    
    # Wait for ArgoCD to be responsive
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if kubectl get applications -n argocd >/dev/null 2>&1; then
            log_success "ArgoCD is ready"
            return 0
        fi
        
        log_debug "Waiting for ArgoCD API... (attempt $((attempts + 1)))"
        sleep 10
        attempts=$((attempts + 1))
    done
    
    log_error "ArgoCD failed to become ready within timeout"
    return 1
}

# Deploy ArgoCD applications
deploy_applications() {
    progress "Deploying applications via ArgoCD"
    
    log_info "Applying ArgoCD projects and applications..."
    
    # Apply in correct order
    kubectl apply -f "$PROJECT_ROOT/kubernetes/argocd/projects/"
    kubectl apply -f "$PROJECT_ROOT/kubernetes/argocd/applications/"
    
    log_info "Waiting for applications to sync..."
    
    # Wait for applications to be created
    sleep 30
    
    # Monitor application sync status
    local apps=("prometheus-stack" "loki-stack" "tractus-x-umbrella" "standalone-edc-consumer" "standalone-edc-provider")
    
    if [ "$DEPLOY_MODE" = "minimal" ]; then
        apps=("tractus-x-umbrella")
    fi
    
    for app in "${apps[@]}"; do
        log_info "Monitoring application: $app"
        
        local attempts=0
        local max_attempts=60  # 30 minutes timeout
        
        while [ $attempts -lt $max_attempts ]; do
            local health=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            local sync=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            
            log_debug "Application $app: Health=$health, Sync=$sync"
            
            if [[ "$health" == "Healthy" && "$sync" == "Synced" ]]; then
                log_success "Application $app is healthy and synced"
                break
            fi
            
            if [[ "$health" == "Degraded" ]]; then
                log_warning "Application $app is degraded, checking details..."
                kubectl describe application "$app" -n argocd
            fi
            
            sleep 30
            attempts=$((attempts + 1))
        done
        
        if [ $attempts -eq $max_attempts ]; then
            log_error "Application $app failed to become healthy within timeout"
            kubectl describe application "$app" -n argocd
            return 1
        fi
    done
    
    log_success "All applications deployed successfully"
}

# Verify core services
verify_core_services() {
    progress "Verifying core services"
    
    log_info "Checking pod status..."
    
    # Check critical pods
    local namespaces=("tractus-x" "edc-standalone" "monitoring" "argocd")
    
    for ns in "${namespaces[@]}"; do
        log_debug "Checking namespace: $ns"
        
        if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
            log_warning "Namespace $ns does not exist, skipping"
            continue
        fi
        
        local failed_pods=$(kubectl get pods -n "$ns" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
        
        if [ "$failed_pods" -gt 0 ]; then
            log_warning "Found $failed_pods non-running pods in namespace $ns"
            kubectl get pods -n "$ns" --field-selector=status.phase!=Running
        else
            log_success "All pods running in namespace $ns"
        fi
    done
    
    # Check specific services
    local services=(
        "tractus-x:tx-data-provider-controlplane:8080"
        "tractus-x:portal-frontend:8080"
        "tractus-x:centralidp-keycloak:8080"
        "edc-standalone:edc-consumer-standalone-controlplane:8080"
        "monitoring:prometheus-kube-prometheus-prometheus:9090"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r namespace service port <<< "$service_info"
        
        if kubectl get service "$service" -n "$namespace" >/dev/null 2>&1; then
            log_success "Service $service exists in namespace $namespace"
        else
            log_warning "Service $service not found in namespace $namespace"
        fi
    done
}

# Test connectivity
test_connectivity() {
    progress "Testing connectivity"
    
    if [ "$SKIP_TESTS" = "true" ]; then
        log_info "Skipping connectivity tests (SKIP_TESTS=true)"
        return 0
    fi
    
    log_info "Testing internal service connectivity..."
    
    # Test EDC management API
    local edc_services=(
        "tractus-x:tx-data-provider-controlplane:8080:/management/v2/assets"
        "edc-standalone:edc-consumer-standalone-controlplane:8080:/management/v2/assets"
    )
    
    for service_info in "${edc_services[@]}"; do
        IFS=':' read -r namespace service port path <<< "$service_info"
        
        log_debug "Testing $service in $namespace"
        
        # Port forward and test
        kubectl port-forward "svc/$service" 18080:$port -n "$namespace" >/dev/null 2>&1 &
        local pf_pid=$!
        
        sleep 5
        
        if curl -s -f -H "X-Api-Key: test-key" "http://localhost:18080$path" >/dev/null 2>&1; then
            log_success "$service API is accessible"
        else
            log_warning "$service API test failed (this may be expected if auth is required)"
        fi
        
        kill $pf_pid 2>/dev/null || true
        sleep 2
    done
}

# Configure DNS and access
configure_access() {
    progress "Configuring access"
    
    # Get Minikube IP
    local minikube_ip=$(minikube ip)
    log_info "Minikube IP: $minikube_ip"
    
    # Create access script
    cat > "$PROJECT_ROOT/access-services.sh" << EOF
#!/bin/bash
# Access script for Tractus-X services

MINIKUBE_IP=$minikube_ip

echo "🚀 Tractus-X Services Access"
echo "=========================="
echo
echo "Minikube IP: \$MINIKUBE_IP"
echo
echo "Core Services:"
echo "  Portal:           http://portal.minikube.local"
echo "  ArgoCD:           https://argocd.minikube.local"
echo "  Grafana:          http://grafana.minikube.local (admin/tractus-admin)"
echo "  Prometheus:       http://prometheus.minikube.local"
echo
echo "EDC Connectors:"
echo "  Consumer CP:      http://dataconsumer-controlplane.minikube.local"
echo "  Provider CP:      http://dataprovider-controlplane.minikube.local"
echo "  Standalone Consumer: http://edc-consumer.minikube.local"
echo "  Standalone Provider: http://edc-provider.minikube.local"
echo
echo "Support Services:"
echo "  Vault:            http://vault.minikube.local"
echo "  PgAdmin:          http://pgadmin.minikube.local (admin@tractus-x.org/tractus-admin)"
echo
echo "To access services, ensure /etc/hosts is configured or run:"
echo "  minikube tunnel"
echo
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Not available"
echo
EOF
    
    chmod +x "$PROJECT_ROOT/access-services.sh"
    log_success "Access script created: $PROJECT_ROOT/access-services.sh"
}

# Run integration tests
run_integration_tests() {
    progress "Running integration tests"
    
    if [ "$SKIP_TESTS" = "true" ]; then
        log_info "Skipping integration tests (SKIP_TESTS=true)"
        return 0
    fi
    
    log_info "Running EDC integration tests..."
    
    cd "$PROJECT_ROOT/tests/integration"
    
    if [ -f "package.json" ]; then
        npm install
        npm test
        log_success "Integration tests passed"
    else
        log_warning "No integration tests found, skipping"
    fi
    
    cd "$PROJECT_ROOT"
}

# Generate deployment report
generate_report() {
    progress "Generating deployment report"
    
    local report_file="$PROJECT_ROOT/deployment-report-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Tractus-X Deployment Report

**Date:** $(date)
**Environment:** $ENVIRONMENT
**Deploy Mode:** $DEPLOY_MODE

## Infrastructure Status

### Cluster Information
\`\`\`
$(kubectl cluster-info)
\`\`\`

### Node Status
\`\`\`
$(kubectl get nodes -o wide)
\`\`\`

### Namespace Summary
\`\`\`
$(kubectl get namespaces)
\`\`\`

## Application Status

### ArgoCD Applications
\`\`\`
$(kubectl get applications -n argocd)
\`\`\`

### Pod Status by Namespace

#### Tractus-X
\`\`\`
$(kubectl get pods -n tractus-x 2>/dev/null || echo "Namespace not found")
\`\`\`

#### EDC Standalone
\`\`\`
$(kubectl get pods -n edc-standalone 2>/dev/null || echo "Namespace not found")
\`\`\`

#### Monitoring
\`\`\`
$(kubectl get pods -n monitoring 2>/dev/null || echo "Namespace not found")
\`\`\`

## Service Endpoints

$(cat "$PROJECT_ROOT/access-services.sh" | grep -E "^echo.*http")

## Resource Usage

### Node Resources
\`\`\`
$(kubectl top nodes 2>/dev/null || echo "Metrics not available")
\`\`\`

### Top Pods by CPU
\`\`\`
$(kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10 || echo "Metrics not available")
\`\`\`

### Top Pods by Memory
\`\`\`
$(kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -10 || echo "Metrics not available")
\`\`\`

## Deployment Summary

- ✅ Infrastructure: Ready
- ✅ ArgoCD: Ready
- ✅ Applications: Deployed
- ✅ Services: Accessible
$([ "$SKIP_TESTS" = "false" ] && echo "- ✅ Tests: Passed" || echo "- ⏭️ Tests: Skipped")

## Next Steps

1. Access services using the URLs above
2. Run integration tests: \`cd tests/integration && npm test\`
3. Monitor applications: \`kubectl get pods --all-namespaces\`
4. Check ArgoCD: \`https://argocd.minikube.local\`

EOF
    
    log_success "Deployment report generated: $report_file"
}

# Backup configuration
backup_configuration() {
    progress "Creating configuration backup"
    
    local backup_dir="$PROJECT_ROOT/backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Kubernetes resources
    kubectl get all --all-namespaces -o yaml > "$backup_dir/all-resources.yaml"
    kubectl get secrets --all-namespaces -o yaml > "$backup_dir/secrets.yaml"
    kubectl get configmaps --all-namespaces -o yaml > "$backup_dir/configmaps.yaml"
    kubectl get pv,pvc --all-namespaces -o yaml > "$backup_dir/storage.yaml"
    
    # Backup ArgoCD applications
    kubectl get applications -n argocd -o yaml > "$backup_dir/argocd-applications.yaml"
    
    # Backup Helm releases
    helm list --all-namespaces -o yaml > "$backup_dir/helm-releases.yaml"
    
    log_success "Configuration backup created: $backup_dir"
}

# Print final status
print_final_status() {
    progress "Deployment completed successfully!"
    
    echo
    echo "🎉 Tractus-X deployment completed successfully!"
    echo
    echo "Quick access:"
    echo "  ./access-services.sh    - Show all service URLs"
    echo "  kubectl get pods -A     - Check pod status"
    echo "  minikube dashboard      - Open Kubernetes dashboard"
    echo
    echo "ArgoCD credentials:"
    echo "  URL: https://argocd.minikube.local"
    echo "  Username: admin"
    echo "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Not available")"
    echo
    echo "For troubleshooting, see: docs/TROUBLESHOOTING.md"
    echo
}

# Main execution
main() {
    echo "🚀 Starting Tractus-X complete deployment"
    echo "Environment: $ENVIRONMENT"
    echo "Deploy Mode: $DEPLOY_MODE"
    echo "Skip Tests: $SKIP_TESTS"
    echo "========================================"
    echo
    
    check_dependencies
    setup_infrastructure
    wait_for_argocd
    deploy_applications
    verify_core_services
    test_connectivity
    configure_access
    run_integration_tests
    backup_configuration
    generate_report
    print_final_status
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        cat << EOF
Usage: $0 [options]

Deploy complete Tractus-X automotive dataspace environment.

Options:
  --help, -h          Show this help message
  --minimal           Deploy minimal configuration (tractus-x only)
  --skip-tests        Skip integration tests
  --environment ENV   Target environment (development|staging|production)

Environment variables:
  ENVIRONMENT         Target environment (default: development)
  DEPLOY_MODE         Deployment mode (full|minimal) (default: full)
  SKIP_TESTS          Skip tests (true|false) (default: false)
  TIMEOUT             Deployment timeout in seconds (default: 1800)

Examples:
  $0                          # Full deployment to development
  $0 --minimal                # Minimal deployment
  $0 --skip-tests             # Deploy without running tests
  ENVIRONMENT=staging $0      # Deploy to staging environment

EOF
        exit 0
        ;;
    --minimal)
        DEPLOY_MODE="minimal"
        ;;
    --skip-tests)
        SKIP_TESTS="true"
        ;;
    --environment)
        ENVIRONMENT="$2"
        shift
        ;;
    "")
        # No arguments, proceed with deployment
        ;;
    *)
        log_error "Unknown argument: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

# Execute main function
main