# terraform/environments/staging.tfvars
# Staging environment configuration

cluster_name = "tractus-x-staging"
environment  = "staging"

# Kubernetes configuration
kubernetes_version = "v1.24.0"
minikube_driver    = "docker"

# Domain configuration
domain_suffix = "staging.example.com"

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
external_dns_enabled    = false

# Backup configuration
backup_retention_days = 14

# Resource quotas for staging
resource_quotas = {
  tractus_x = {
    cpu_requests    = "2"
    cpu_limits      = "4"
    memory_requests = "4Gi"
    memory_limits   = "8Gi"
    storage         = "20Gi"
  }
  edc_standalone = {
    cpu_requests    = "1"
    cpu_limits      = "2"
    memory_requests = "2Gi"
    memory_limits   = "4Gi"
    storage         = "10Gi"
  }
  monitoring = {
    cpu_requests    = "1"
    cpu_limits      = "2"
    memory_requests = "2Gi"
    memory_limits   = "4Gi"
    storage         = "10Gi"
  }
}