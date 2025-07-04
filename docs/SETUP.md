# Setup Instructions

This guide provides detailed step-by-step instructions for setting up the Tractus-X DevOps deployment environment.

## Prerequisites

### System Requirements

**Minimum Requirements:**
- CPU: 4 cores
- RAM: 8 GB
- Storage: 20 GB free space
- OS: Linux, macOS, or Windows with WSL2

**Recommended Requirements:**
- CPU: 8 cores
- RAM: 16 GB
- Storage: 50 GB free space

### Required Software

1. **Docker Desktop or Docker Engine**
   ```bash
   # Linux (Ubuntu/Debian)
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # macOS
   brew install --cask docker
   
   # Windows
   # Download from https://www.docker.com/products/docker-desktop
   ```

2. **Minikube**
   ```bash
   # Linux
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   
   # macOS
   brew install minikube
   
   # Windows
   winget install Kubernetes.minikube
   ```

3. **kubectl**
   ```bash
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   
   # macOS
   brew install kubectl
   
   # Windows
   winget install Kubernetes.kubectl
   ```

4. **Helm**
   ```bash
   # Linux/macOS
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   
   # Windows
   winget install Helm.Helm
   ```

5. **Terraform**
   ```bash
   # Linux/macOS
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   
   # macOS
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform
   
   # Windows
   winget install HashiCorp.Terraform
   ```

6. **Python 3.8+** (for testing)
   ```bash
   # Linux (Ubuntu/Debian)
   sudo apt update && sudo apt install python3 python3-pip
   
   # macOS
   brew install python3
   
   # Windows
   winget install Python.Python.3
   ```

7. **ArgoCD CLI** (optional but recommended)
   ```bash
   # Linux
   curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
   sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
   
   # macOS
   brew install argocd
   
   # Windows
   winget install ArgoProj.ArgoCD
   ```

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd tractus-x-devops
```

### Step 2: Install Tools (Automated)

Use the provided script to install all required tools:

```bash
chmod +x scripts/install-tools.sh
./scripts/install-tools.sh
```

This script will:
- Verify existing installations
- Install missing tools
- Configure tool versions
- Set up shell completions

### Step 3: Configure Environment

1. **Set up environment variables**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Edit configuration
   nano .env
   ```

   Example `.env` file:
   ```bash
   # Minikube Configuration
   MINIKUBE_MEMORY=8192
   MINIKUBE_CPUS=4
   MINIKUBE_DISK_SIZE=20GB
   MINIKUBE_DRIVER=docker
   
   # Cluster Configuration
   CLUSTER_NAME=tractus-x-dev
   KUBERNETES_VERSION=v1.28.0
   
   # Namespace Configuration
   NAMESPACE_TRACTUS_X=tractus-x
   NAMESPACE_EDC=edc-standalone
   NAMESPACE_MONITORING=monitoring
   NAMESPACE_ARGOCD=argocd
   
   # Monitoring Configuration
   ENABLE_PROMETHEUS=true
   ENABLE_GRAFANA=true
   ENABLE_LOKI=true
   ENABLE_ALERTMANAGER=true
   
   # Security Configuration
   ENABLE_RBAC=true
   ENABLE_NETWORK_POLICIES=true
   
   # Development Configuration
   DEBUG_MODE=true
   LOG_LEVEL=INFO
   ```

2. **Configure Docker resources** (if using Docker Desktop)
   - Memory: At least 8 GB
   - CPUs: At least 4 cores
   - Disk space: At least 20 GB

### Step 4: Initialize Minikube

```bash
# Start Minikube with appropriate resources
./scripts/setup-minikube.sh
```

This script will:
- Start Minikube with optimized settings
- Enable required addons (ingress, metrics-server, etc.)
- Configure DNS and networking
- Verify cluster health

**Manual Minikube setup (if script fails):**
```bash
# Delete existing cluster
minikube delete

# Start with specific configuration
minikube start \
  --memory=8192 \
  --cpus=4 \
  --disk-size=20GB \
  --driver=docker \
  --kubernetes-version=v1.28.0

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable storage-provisioner
```

### Step 5: Deploy Infrastructure with Terraform

1. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

2. **Review and customize variables**
   ```bash
   # Edit terraform variables
   nano terraform.tfvars
   ```

   Example `terraform.tfvars`:
   ```hcl
   cluster_name = "tractus-x-dev"
   namespace_tractus_x = "tractus-x"
   namespace_edc = "edc-standalone"
   namespace_monitoring = "monitoring"
   namespace_argocd = "argocd"
   
   # Monitoring configuration
   enable_prometheus = true
   enable_grafana = true
   enable_loki = true
   prometheus_retention = "15d"
   grafana_admin_password = "tractus-x-admin"
   
   # EDC configuration
   edc_control_plane_replicas = 1
   edc_data_plane_replicas = 1
   edc_image_tag = "latest"
   
   # ArgoCD configuration
   argocd_admin_password = "tractus-x-admin"
   argocd_repo_url = "https://github.com/your-org/tractus-x-devops"
   argocd_target_revision = "HEAD"
   
   # Ingress configuration
   enable_ingress = true
   ingress_domain = "minikube.local"
   enable_tls = false
   
   # Resource limits
   default_cpu_limit = "500m"
   default_memory_limit = "512Mi"
   default_cpu_request = "100m"
   default_memory_request = "128Mi"
   ```

3. **Plan deployment**
   ```bash
   terraform plan -out=tfplan
   ```

4. **Apply infrastructure**
   ```bash
   terraform apply tfplan
   ```

This will deploy:
- Kubernetes namespaces
- ArgoCD installation
- Monitoring stack (Prometheus, Grafana, Loki)
- Ingress configuration
- Required secrets and configmaps

### Step 6: Configure ArgoCD

1. **Get ArgoCD admin password**
   ```bash
   kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. **Port forward to ArgoCD UI**
   ```bash
   kubectl port-forward -n argocd svc/argocd-server 8080:443
   ```

3. **Access ArgoCD UI**
   - URL: https://localhost:8080
   - Username: `admin`
   - Password: (from step 1)

4. **Configure repositories** (if not done via Terraform)
   ```bash
   # Login to ArgoCD CLI
   argocd login localhost:8080 --username admin --password <password> --insecure
   
   # Add this repository to ArgoCD
   argocd repo add <repository-url> --type git --name tractus-x-devops
   
   # Verify repository
   argocd repo list
   ```

### Step 7: Deploy Applications

1. **Deploy all applications using the script**
   ```bash
   ./scripts/deploy-all.sh
   ```

2. **Or deploy manually via ArgoCD**
   ```bash
   # Apply ArgoCD applications
   kubectl apply -f kubernetes/argocd/applications/
   
   # Verify applications
   kubectl get applications -n argocd
   ```

The deployment script will:
- Deploy Tractus-X umbrella project
- Deploy standalone EDC connectors
- Configure monitoring dashboards
- Set up ingress rules
- Verify all deployments

### Step 8: Verify Installation

1. **Check ArgoCD applications**
   ```bash
   kubectl get applications -n argocd
   argocd app list
   ```

2. **Verify pods are running**
   ```bash
   kubectl get pods -A
   kubectl get pods -n tractus-x
   kubectl get pods -n edc-standalone
   kubectl get pods -n monitoring
   ```

3. **Check service endpoints**
   ```bash
   minikube service list
   kubectl get svc -A
   ```

4. **Run health checks**
   ```bash
   # Test EDC connectors
   curl $(minikube service -n tractus-x edc-control-plane --url)/api/check/health
   curl $(minikube service -n edc-standalone edc-control-plane --url)/api/check/health
   
   # Test monitoring endpoints
   curl $(minikube service -n monitoring prometheus-server --url)/api/v1/targets
   curl $(minikube service -n monitoring grafana --url)/api/health
   
   # Test ArgoCD
   curl -k $(minikube service -n argocd argocd-server --url)/api/version
   ```

## Environment-Specific Configuration

### Development Environment

For development, use minimal resource allocation:

```bash
# Minikube with minimal resources
minikube start --memory=6144 --cpus=2

# Disable resource-intensive features
export ENABLE_MONITORING=false
export ENABLE_TRACING=false
export ENABLE_ALERTMANAGER=false
```

Create a development-specific `terraform.tfvars`:
```hcl
# Development configuration
enable_prometheus = true
enable_grafana = true
enable_loki = false
enable_alertmanager = false

# Minimal resource allocation
edc_control_plane_replicas = 1
edc_data_plane_replicas = 1

# Reduced retention
prometheus_retention = "7d"
loki_retention = "24h"
```

### Staging Environment

For staging, use production-like settings:

```bash
# Minikube with more resources
minikube start --memory=12288 --cpus=6

# Enable all monitoring features
export ENABLE_MONITORING=true
export ENABLE_TRACING=true
export ENABLE_ALERTMANAGER=true
```

Staging `terraform.tfvars`:
```hcl
# Staging configuration
enable_prometheus = true
enable_grafana = true
enable_loki = true
enable_alertmanager = true

# Production-like resources
edc_control_plane_replicas = 2
edc_data_plane_replicas = 2

# Extended retention
prometheus_retention = "30d"
loki_retention = "7d"

# Resource limits
default_cpu_limit = "1000m"
default_memory_limit = "1Gi"
```

### Production Environment

For production deployment on managed Kubernetes:

```bash
# Use managed Kubernetes instead of Minikube
# Configure kubectl for your managed cluster
kubectl config use-context <production-context>
```

Production `terraform.tfvars`:
```hcl
# Production configuration
cluster_name = "tractus-x-prod"
enable_prometheus = true
enable_grafana = true
enable_loki = true
enable_alertmanager = true

# High availability
edc_control_plane_replicas = 3
edc_data_plane_replicas = 3

# Production retention
prometheus_retention = "90d"
loki_retention = "30d"

# Production ingress
enable_ingress = true
ingress_domain = "tractus-x.example.com"
enable_tls = true

# Production resources
default_cpu_limit = "2000m"
default_memory_limit = "2Gi"
default_cpu_request = "500m"
default_memory_request = "512Mi"
```

### Multi-Node Setup (Advanced)

For multi-node testing using KinD instead of Minikube:

1. **Install KinD**
   ```bash
   # Linux/macOS
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
   chmod +x ./kind
   sudo mv ./kind /usr/local/bin/kind
   
   # macOS
   brew install kind
   ```

2. **Create KinD cluster configuration**
   ```yaml
   # configs/kind-cluster.yaml
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   nodes:
   - role: control-plane
     kubeadmConfigPatches:
     - |
       kind: InitConfiguration
       nodeRegistration:
         kubeletExtraArgs:
           node-labels: "ingress-ready=true"
     extraPortMappings:
     - containerPort: 80
       hostPort: 80
       protocol: TCP
     - containerPort: 443
       hostPort: 443
       protocol: TCP
   - role: worker
   - role: worker
   ```

3. **Create multi-node cluster**
   ```bash
   kind create cluster --config configs/kind-cluster.yaml --name tractus-x
   ```

## Testing Setup

### Install Test Dependencies

```bash
cd tests
pip install -r requirements.txt
```

### Configure Test Environment

```bash
# Set test environment variables
export KUBECONFIG=~/.kube/config
export TEST_NAMESPACE=tractus-x
export EDC_NAMESPACE=edc-standalone
export MONITORING_NAMESPACE=monitoring
export ARGOCD_NAMESPACE=argocd

# Test configuration
export TEST_TIMEOUT=300
export TEST_RETRY_COUNT=3
export TEST_PARALLEL_WORKERS=4
```

### Run Test Suite

```bash
# Integration tests
pytest tests/integration/ -v

# E2E tests (requires full deployment)
pytest tests/e2e/ -v --tb=short

# Performance tests
pytest tests/performance/ -v -m "not stress"

# Generate test report
pytest tests/ --html=reports/test-report.html --self-contained-html
```

### Continuous Testing

Set up automated testing during development:

```bash
# Install pytest-watch for continuous testing
pip install pytest-watch

# Run tests continuously
ptw tests/integration/ -- -v
```

## Networking Configuration

### Ingress Setup

The deployment uses Nginx Ingress Controller with the following domains:

- `tractus-x.minikube.local` - Tractus-X Portal
- `argocd.minikube.local` - ArgoCD UI
- `grafana.minikube.local` - Grafana Dashboards
- `prometheus.minikube.local` - Prometheus UI

Add these to your `/etc/hosts` file:
```bash
echo "$(minikube ip) tractus-x.minikube.local argocd.minikube.local grafana.minikube.local prometheus.minikube.local" | sudo tee -a /etc/hosts
```

### Port Forwarding (Alternative)

If ingress is not working, use port forwarding:

```bash
# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Tractus-X Portal
kubectl port-forward -n tractus-x svc/portal 8081:80
```

### Custom Domain Configuration

For custom domain setup:

1. **Configure DNS**
   ```bash
   # Add custom domain to /etc/hosts
   echo "$(minikube ip) tractus-x.local argocd.local grafana.local" | sudo tee -a /etc/hosts
   ```

2. **Update Terraform variables**
   ```hcl
   ingress_domain = "local"
   ```

3. **Apply changes**
   ```bash
   terraform apply
   ```

## SSL/TLS Configuration

### Self-Signed Certificates

For development with self-signed certificates:

1. **Generate certificates**
   ```bash
   # Create certificate directory
   mkdir -p certs

   # Generate CA private key
   openssl genrsa -out certs/ca.key 4096

   # Generate CA certificate
   openssl req -new -x509 -key certs/ca.key -sha256 -subj "/C=US/ST=CA/O=Tractus-X/CN=Tractus-X CA" -days 3650 -out certs/ca.crt

   # Generate server private key
   openssl genrsa -out certs/server.key 4096

   # Generate server certificate signing request
   openssl req -new -key certs/server.key -out certs/server.csr -config <(
   cat <<EOF
   [req]
   distinguished_name = req_distinguished_name
   req_extensions = v3_req
   prompt = no
   [req_distinguished_name]
   C = US
   ST = CA
   L = San Francisco
   O = Tractus-X
   CN = *.minikube.local
   [v3_req]
   keyUsage = keyEncipherment, dataEncipherment
   extendedKeyUsage = serverAuth
   subjectAltName = @alt_names
   [alt_names]
   DNS.1 = *.minikube.local
   DNS.2 = minikube.local
   EOF
   )

   # Generate server certificate
   openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/server.crt -days 365 -extensions v3_req -extfile <(
   cat <<EOF
   [v3_req]
   keyUsage = keyEncipherment, dataEncipherment
   extendedKeyUsage = serverAuth
   subjectAltName = @alt_names
   [alt_names]
   DNS.1 = *.minikube.local
   DNS.2 = minikube.local
   EOF
   )
   ```

2. **Create Kubernetes secret**
   ```bash
   kubectl create secret tls tractus-x-tls --cert=certs/server.crt --key=certs/server.key -n tractus-x
   kubectl create secret tls argocd-server-tls --cert=certs/server.crt --key=certs/server.key -n argocd
   ```

3. **Update Terraform variables**
   ```hcl
   enable_tls = true
   ```

## Backup and Recovery

### Backup Configuration

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup ArgoCD configuration
kubectl get applications -n argocd -o yaml > backups/$(date +%Y%m%d)/argocd-apps.yaml
kubectl get appprojects -n argocd -o yaml > backups/$(date +%Y%m%d)/argocd-projects.yaml

# Backup secrets
kubectl get secrets -A -o yaml > backups/$(date +%Y%m%d)/secrets.yaml

# Backup configmaps
kubectl get configmaps -A -o yaml > backups/$(date +%Y%m%d)/configmaps.yaml

# Backup persistent volumes
kubectl get pv -o yaml > backups/$(date +%Y%m%d)/pv.yaml
kubectl get pvc -A -o yaml > backups/$(date +%Y%m%d)/pvc.yaml

# Backup custom resources
kubectl get crds -o yaml > backups/$(date +%Y%m%d)/crds.yaml
```

### Recovery Procedure

```bash
# Restore from backup
kubectl apply -f backups/20240101/argocd-apps.yaml
kubectl apply -f backups/20240101/argocd-projects.yaml
kubectl apply -f backups/20240101/secrets.yaml
kubectl apply -f backups/20240101/configmaps.yaml
```

### Automated Backup Script

```bash
#!/bin/bash
# scripts/backup.sh

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Creating backup in $BACKUP_DIR"

# Backup cluster state
kubectl cluster-info dump --output-directory="$BACKUP_DIR/cluster-dump"

# Backup specific resources
resources=("applications" "appprojects" "secrets" "configmaps" "pv" "pvc")
for resource in "${resources[@]}"; do
    kubectl get "$resource" -A -o yaml > "$BACKUP_DIR/$resource.yaml"
done

# Compress backup
tar -czf "$BACKUP_DIR.tar.gz" -C backups "$(basename $BACKUP_DIR)"
rm -rf "$BACKUP_DIR"

echo "Backup completed: $BACKUP_DIR.tar.gz"
```

## Troubleshooting Setup Issues

### Common Problems

1. **Minikube won't start**
   ```bash
   # Check Docker is running
   docker version
   
   # Reset Minikube
   minikube delete
   minikube start --memory=8192 --cpus=4
   
   # Check available resources
   docker system df
   docker system prune -f
   ```

2. **Insufficient resources**
   ```bash
   # Check available resources
   minikube status
   kubectl top nodes
   
   # Increase Minikube resources
   minikube config set memory 12288
   minikube config set cpus 6
   minikube delete && minikube start
   ```

3. **ArgoCD applications not syncing**
   ```bash
   # Check ArgoCD server logs
   kubectl logs -n argocd deployment/argocd-server
   
   # Check repository connectivity
   kubectl logs -n argocd deployment/argocd-repo-server
   
   # Refresh applications
   kubectl patch application -n argocd tractus-x-umbrella --type json -p='[{"op": "replace", "path": "/operation", "value": null}]'
   ```

4. **EDC connectors not starting**
   ```bash
   # Check pod logs
   kubectl logs -n tractus-x deployment/edc-control-plane
   
   # Check resource constraints
   kubectl describe pod -n tractus-x -l app.kubernetes.io/name=edc
   
   # Check configuration
   kubectl get configmap -n tractus-x -o yaml
   ```

5. **Terraform apply failures**
   ```bash
   # Check Terraform state
   terraform state list
   terraform state show <resource>
   
   # Refresh state
   terraform refresh
   
   # Targeted apply
   terraform apply -target=<resource>
   ```

### Performance Optimization

1. **Minikube Performance**
   ```bash
   # Use faster storage driver
   minikube start --driver=docker --mount-string="/tmp:/tmp" --mount
   
   # Enable resource monitoring
   minikube addons enable metrics-server
   ```

2. **Container Performance**
   ```bash
   # Optimize container resources
   kubectl patch deployment -n tractus-x edc-control-plane -p='{"spec":{"template":{"spec":{"containers":[{"name":"edc-control-plane","resources":{"limits":{"cpu":"1000m","memory":"1Gi"},"requests":{"cpu":"500m","memory":"512Mi"}}}]}}}}'
   ```

### Getting Help

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review pod logs: `kubectl logs -f <pod-name> -n <namespace>`
3. Check resource usage: `kubectl top pods -A`
4. Examine events: `kubectl get events -A --sort-by='.lastTimestamp'`
5. Verify service connectivity: `kubectl exec -it <pod> -- curl <service-url>`

### Useful Debugging Commands

```bash
# Cluster debugging
kubectl cluster-info dump
kubectl get nodes -o wide
kubectl describe node minikube

# Pod debugging
kubectl get pods -A -o wide
kubectl describe pod <pod-name> -n <namespace>
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Service debugging
kubectl get svc -A
kubectl get endpoints -A
kubectl describe svc <service-name> -n <namespace>

# Network debugging
kubectl get ingress -A
kubectl get networkpolicies -A
kubectl exec -it <pod> -- nslookup <service-name>

# Storage debugging
kubectl get pv,pvc -A
kubectl describe pvc <pvc-name> -n <namespace>
```

## Next Steps

After successful setup:

1. **Explore the services**
   - Access Grafana dashboards
   - Review ArgoCD applications
   - Test EDC connector APIs

2. **Run the test suite**
   - Validate integration tests
   - Execute E2E workflows
   - Check performance benchmarks

3. **Customize for your needs**
   - Modify Helm values
   - Add custom dashboards
   - Configure additional monitoring

4. **Set up CI/CD**
   - Configure GitHub Actions
   - Set up automated deployments
   - Enable GitOps workflows

For detailed operational procedures, see the [Operational Playbook](OPERATIONAL-PLAYBOOK.md).