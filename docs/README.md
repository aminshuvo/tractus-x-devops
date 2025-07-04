# Tractus-X DevOps Deployment

This repository contains a complete Infrastructure as Code (IaC) solution for deploying the Tractus-X umbrella project with standalone Eclipse Dataspace Components (EDC) connectors using Kubernetes, ArgoCD, and comprehensive observability.

## 🏗️ Architecture Overview

The deployment consists of:

- **Tractus-X Umbrella Project**: Core services deployed via Helm charts
- **Standalone EDC Connectors**: Independent EDC instances for peer-to-peer integration testing
- **Infrastructure as Code**: Terraform-managed infrastructure including Minikube, ArgoCD, and monitoring
- **Observability Stack**: Prometheus, Grafana, and Loki for comprehensive monitoring and logging
- **CI/CD Pipeline**: GitHub Actions with GitOps via ArgoCD
- **Testing Suite**: Integration, E2E, and performance tests

## 🚀 Quick Start

### Prerequisites

- Docker Desktop or Docker Engine
- Minikube
- kubectl
- Helm 3.x
- Terraform >= 1.0
- Python 3.8+ (for testing)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd tractus-x-devops
   ```

2. **Install required tools**
   ```bash
   ./scripts/install-tools.sh
   ```

3. **Setup Minikube cluster**
   ```bash
   ./scripts/setup-minikube.sh
   ```

4. **Deploy infrastructure**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

5. **Deploy all services**
   ```bash
   ./scripts/deploy-all.sh
   ```

### Access Services

After deployment, services will be available at:

- **ArgoCD**: `https://argocd.minikube.local`
- **Grafana**: `http://grafana.minikube.local`
- **Prometheus**: `http://prometheus.minikube.local`
- **Tractus-X Portal**: `http://tractus-x.minikube.local`

Get service URLs:
```bash
minikube service list
```

## 📁 Project Structure

```
tractus-x-devops/
├── .github/workflows/     # GitHub Actions CI/CD pipelines
│   ├── infrastructure.yml       # Infrastructure provisioning
│   ├── deploy-umbrella.yml     # Tractus-X umbrella deployment
│   ├── deploy-edc.yml          # Standalone EDC deployment
│   └── monitoring.yml          # Observability stack
├── terraform/            # Infrastructure as Code
│   ├── main.tf                 # Main infrastructure definition
│   ├── minikube.tf             # Minikube cluster configuration
│   ├── argocd.tf               # ArgoCD setup
│   ├── monitoring.tf           # Observability infrastructure
│   └── variables.tf            # Configuration variables
├── kubernetes/           # Kubernetes manifests and ArgoCD configs
│   ├── argocd/
│   │   ├── applications/       # ArgoCD Application manifests
│   │   └── projects/           # ArgoCD Project definitions
│   ├── tractus-x/
│   │   ├── base/               # Base Kustomize configurations
│   │   ├── overlays/           # Environment-specific overlays
│   │   └── values/             # Helm values files
│   ├── edc-standalone/
│   │   ├── manifests/          # Standalone EDC manifests
│   │   ├── config/             # EDC configuration files
│   │   └── values/             # Helm values for EDC
│   └── monitoring/
│       ├── prometheus/         # Prometheus configuration
│       ├── grafana/            # Grafana dashboards
│       └── loki/               # Loki logging setup
├── scripts/             # Deployment and utility scripts
│   ├── setup-minikube.sh      # Minikube initialization
│   ├── install-tools.sh       # Required tools installation
│   ├── deploy-all.sh          # Complete deployment script
│   └── cleanup.sh             # Environment cleanup
├── configs/             # Service configurations
│   ├── prometheus/            # Prometheus configurations
│   ├── grafana/               # Grafana configurations
│   └── loki/                  # Loki configurations
├── tests/               # Comprehensive test suite
│   ├── integration/           # Integration tests
│   ├── e2e/                   # End-to-end tests
│   └── performance/           # Performance tests
└── /                # Documentation
    ├── README.md              # Main documentation
    ├── SETUP.md               # Setup instructions
    ├── OPERATIONAL-PLAYBOOK.md # Operations guide
    ├── ARCHITECTURE.md        # Architecture documentation
    └── TROUBLESHOOTING.md     # Troubleshooting guide
```

## 🛠️ Components

### Infrastructure (Terraform)
- Minikube cluster configuration
- ArgoCD installation and setup
- Monitoring stack deployment
- Ingress and networking configuration

### Kubernetes Deployment
- **Tractus-X Umbrella**: Portal, IAM, Discovery Service, etc.
- **EDC Connectors**: Control plane and data plane components
- **Monitoring**: Prometheus, Grafana, Loki stack
- **ArgoCD**: GitOps deployment management

### Observability
- **Metrics**: Prometheus with custom EDC and Tractus-X dashboards
- **Logging**: Loki with Promtail for log aggregation
- **Dashboards**: Pre-configured Grafana dashboards
- **Alerting**: Prometheus alert rules for critical conditions

## 🔄 CI/CD Pipeline

The project uses GitHub Actions for CI/CD with the following workflows:

1. **Infrastructure Pipeline** (`.github/workflows/infrastructure.yml`)
   - Terraform validation and planning
   - Infrastructure provisioning
   - Environment setup

2. **Application Deployment** (`.github/workflows/deploy-umbrella.yml`)
   - Helm chart validation
   - Tractus-X umbrella deployment
   - Health checks and validation

3. **EDC Deployment** (`.github/workflows/deploy-edc.yml`)
   - Standalone EDC connector deployment
   - Inter-connector communication tests

4. **Monitoring Setup** (`.github/workflows/monitoring.yml`)
   - Observability stack deployment
   - Dashboard and alert configuration

### GitOps with ArgoCD

ArgoCD manages application deployments with:
- Automatic sync from Git repositories
- Environment-specific configurations
- Rollback capabilities
- Visual deployment monitoring

## 🧪 Testing

### Test Suite Components

1. **Integration Tests** (`tests/integration/`)
   - Kubernetes cluster validation
   - Service health checks
   - ArgoCD application sync verification

2. **End-to-End Tests** (`tests/e2e/`)
   - Complete EDC data exchange workflow
   - Contract negotiation and data transfer
   - Observability pipeline validation

3. **Performance Tests** (`tests/performance/`)
   - Load testing for EDC endpoints
   - Resource usage monitoring
   - Stress testing and limits

### Running Tests

```bash
# Install test dependencies
pip install -r tests/requirements.txt

# Run integration tests
pytest tests/integration/ -v

# Run E2E tests (requires deployed environment)
pytest tests/e2e/ -v

# Run performance tests
pytest tests/performance/ -v
```

## 🔐 Security

### Secrets Management
- Kubernetes secrets for sensitive data
- Sealed secrets for GitOps workflows
- Service account-based authentication

### Network Security
- Ingress controller with TLS termination
- Network policies for pod-to-pod communication
- Service mesh considerations (optional)

### EDC Security
- Mutual TLS for connector communication
- JWT-based authentication
- Policy-based access control

## 📊 Monitoring and Observability

### Key Metrics Monitored
- **Kubernetes**: Pod status, resource usage, node health
- **EDC**: Contract negotiations, data transfers, policy evaluations
- **Tractus-X**: Service availability, API response times
- **Infrastructure**: CPU, memory, storage, network

### Pre-configured Dashboards
- Tractus-X Overview
- EDC Connector Performance
- Kubernetes Cluster Health
- Infrastructure Metrics

### Alerting Rules
- Pod crash looping
- High resource usage
- EDC connector failures
- Certificate expiration

## 🌍 Environment Management

### Supported Environments
- **Development**: Local Minikube with minimal resources
- **Staging**: Enhanced configuration with full monitoring
- **Production**: Production-ready settings with high availability

### Configuration Management
Environment-specific configurations are managed through:
- Kustomize overlays for Kubernetes manifests
- Helm values files for different environments
- Terraform workspace variables

## 🚨 Troubleshooting

### Common Issues

1. **Minikube startup issues**
   ```bash
   minikube delete
   minikube start --memory=8192 --cpus=4
   ```

2. **ArgoCD sync failures**
   ```bash
   kubectl get applications -n argocd
   kubectl describe application <app-name> -n argocd
   ```

3. **EDC connector not responding**
   ```bash
   kubectl logs -n tractus-x deployment/edc-control-plane
   kubectl logs -n edc-standalone deployment/edc-control-plane
   ```

### Getting Help
- Check the [Troubleshooting Guide](/TROUBLESHOOTING.md)
- Review application logs using Grafana/Loki
- Examine Prometheus alerts for system issues

## 📚 Documentation

- [Setup Instructions](/SETUP.md) - Detailed setup and configuration
- [Operational Playbook](/OPERATIONAL-PLAYBOOK.md) - Production operations guide
- [Architecture Documentation](/ARCHITECTURE.md) - System architecture and design
- [Troubleshooting Guide](/TROUBLESHOOTING.md) - Common issues and solutions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Development Workflow
```bash
# Setup development environment
./scripts/setup-minikube.sh

# Make changes and test
pytest tests/integration/ -v

# Deploy and validate
./scripts/deploy-all.sh
pytest tests/e2e/ -v
```

## 📄 License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- Create an issue in this repository
- Check the documentation in the `/` directory
- Review existing issues for similar problems

## 🏷️ Version Information

- **Tractus-X Release**: Latest stable
- **EDC Version**: Latest from Eclipse Dataspace Components
- **Kubernetes**: 1.28+
- **ArgoCD**: 2.8+
- **Terraform**: 1.0+

## 📈 Performance Characteristics

### Expected Performance Metrics
- **API Response Time**: < 200ms (95th percentile)
- **Data Transfer Rate**: > 100 MB/s
- **Contract Negotiation**: < 30 seconds
- **Dashboard Load Time**: < 3 seconds

### Resource Requirements

**Minimum (Development):**
- CPU: 4 cores
- RAM: 8 GB
- Storage: 20 GB

**Recommended (Staging/Production):**
- CPU: 8+ cores
- RAM: 16+ GB
- Storage: 50+ GB

## 🔧 Configuration Options

### Terraform Variables

Key configuration options in `terraform/variables.tf`:

```hcl
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "tractus-x-dev"
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "edc_replicas" {
  description = "Number of EDC connector replicas"
  type        = number
  default     = 1
}
```

### Environment Variables

Key environment variables for configuration:

```bash
# Minikube configuration
MINIKUBE_MEMORY=8192
MINIKUBE_CPUS=4
MINIKUBE_DISK_SIZE=20GB

# Application configuration
ENABLE_MONITORING=true
ENABLE_TRACING=false
LOG_LEVEL=INFO

# ArgoCD configuration
ARGOCD_REPO_URL=https://github.com/your-org/tractus-x-devops
ARGOCD_TARGET_REVISION=HEAD
```

## 🔄 Upgrade Process

### Infrastructure Upgrades

1. **Terraform Updates**
   ```bash
   cd terraform
   terraform plan
   terraform apply
   ```

2. **Kubernetes Cluster Updates**
   ```bash
   minikube start --kubernetes-version=v1.29.0
   ```

### Application Upgrades

1. **GitOps-based Updates**
   - Update Helm chart versions in Git repository
   - ArgoCD automatically detects and applies changes

2. **Manual Updates**
   ```bash
   helm upgrade tractus-x ./charts/tractus-x -n tractus-x
   ```

## 🏆 Best Practices

### Development
- Use feature branches for all changes
- Write tests for new functionality
- Follow semantic versioning for releases
- Document configuration changes

### Operations
- Regular backup verification
- Monitor resource usage trends
- Keep security patches current
- Test disaster recovery procedures

### Security
- Rotate secrets regularly
- Use least privilege access
- Enable audit logging
- Regular security scans

---

**Note**: This deployment is designed for development and testing purposes. For production deployments, please review the [Operational Playbook](/OPERATIONAL-PLAYBOOK.md) for additional security and reliability considerations.
