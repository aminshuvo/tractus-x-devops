# terraform/environments/production.tfvars
# Production environment configuration

cluster_name = "tractus-x-prod"
environment  = "production"

# Kubernetes configuration
kubernetes_version = "v1.24.0"
minikube_driver    = "docker"

# Domain configuration
domain_suffix = "tractus-x.org"

# Tool versions
argocd_version        = "5.46.7"
sealed_secrets_version = "2.13.2"
tractus_x_version     = "24.08.1"

# Feature flags
enable_monitoring         = true
enable_tracing           = true
enable_development_tools = false
network_policies_enabled = true
pod_security_standards   = "restricted"
tls_enabled             = true
cert_manager_enabled    = true
external_dns_enabled    = true

# Backup configuration
backup_retention_days = 30

# Resource quotas for production
resource_quotas = {
  tractus_x = {
    cpu_requests    = "4"
    cpu_limits      = "8"
    memory_requests = "8Gi"
    memory_limits   = "16Gi"
    storage         = "50Gi"
  }
  edc_standalone = {
    cpu_requests    = "2"
    cpu_limits      = "4"
    memory_requests = "4Gi"
    memory_limits   = "8Gi"
    storage         = "20Gi"
  }
  monitoring = {
    cpu_requests    = "2"
    cpu_limits      = "4"
    memory_requests = "4Gi"
    memory_limits   = "8Gi"
    storage         = "20Gi"
  }
}