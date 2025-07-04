# terraform/environments/development.tfvars
# Development environment configuration

cluster_name = "tractus-x-dev"
environment  = "development"

# Kubernetes configuration
kubernetes_version = "v1.24.0"
minikube_driver    = "docker"

# Domain configuration
domain_suffix = "minikube.local"

# Tool versions
argocd_version        = "5.46.7"
sealed_secrets_version = "2.13.2"
tractus_x_version     = "24.08.1"

# Feature flags
enable_monitoring         = true
enable_tracing           = true
enable_development_tools = true
network_policies_enabled = false  # Relaxed for development
pod_security_standards   = "baseline"
tls_enabled             = false
cert_manager_enabled    = false
external_dns_enabled    = false

# Backup configuration
backup_retention_days = 7

# Resource quotas for development
resource_quotas = {
  tractus_x = {
    cpu_requests    = "1"
    cpu_limits      = "2"
    memory_requests = "2Gi"
    memory_limits   = "4Gi"
    storage         = "10Gi"
  }
  edc_standalone = {
    cpu_requests    = "0.5"
    cpu_limits      = "1"
    memory_requests = "1Gi"
    memory_limits   = "2Gi"
    storage         = "5Gi"
  }
  monitoring = {
    cpu_requests    = "0.5"
    cpu_limits      = "1"
    memory_requests = "1Gi"
    memory_limits   = "2Gi"
    storage         = "5Gi"
  }
}