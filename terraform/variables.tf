# terraform/variables.tf

variable "cluster_name" {
  description = "Name of the Minikube cluster"
  type        = string
  default     = "tractus-x-dev"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for Minikube"
  type        = string
  default     = "v1.24.0"
}

variable "minikube_driver" {
  description = "Minikube driver to use"
  type        = string
  default     = "docker"
  
  validation {
    condition     = contains(["docker", "virtualbox", "hyperkit", "kvm2"], var.minikube_driver)
    error_message = "Minikube driver must be one of: docker, virtualbox, hyperkit, kvm2."
  }
}

variable "domain_suffix" {
  description = "Domain suffix for local development"
  type        = string
  default     = "minikube.local"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.46.7"
}

variable "sealed_secrets_version" {
  description = "Sealed Secrets controller version"
  type        = string
  default     = "2.13.2"
}

variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus, Grafana, Loki)"
  type        = bool
  default     = true
}

variable "enable_tracing" {
  description = "Enable distributed tracing with Jaeger"
  type        = bool
  default     = false
}

variable "tractus_x_version" {
  description = "Tractus-X umbrella chart version"
  type        = string
  default     = "24.08.1"
}

variable "enable_development_tools" {
  description = "Enable development tools (debug logs, hot reload, etc.)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days > 0 && var.backup_retention_days <= 90
    error_message = "Backup retention days must be between 1 and 90."
  }
}

variable "resource_quotas" {
  description = "Resource quotas for namespaces"
  type = object({
    tractus_x = object({
      cpu_requests    = string
      cpu_limits      = string
      memory_requests = string
      memory_limits   = string
      storage         = string
    })
    edc_standalone = object({
      cpu_requests    = string
      cpu_limits      = string
      memory_requests = string
      memory_limits   = string
      storage         = string
    })
    monitoring = object({
      cpu_requests    = string
      cpu_limits      = string
      memory_requests = string
      memory_limits   = string
      storage         = string
    })
  })
  
  default = {
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
}

variable "network_policies_enabled" {
  description = "Enable network policies for enhanced security"
  type        = bool
  default     = true
}

variable "pod_security_standards" {
  description = "Pod Security Standards enforcement level"
  type        = string
  default     = "restricted"
  
  validation {
    condition     = contains(["privileged", "baseline", "restricted"], var.pod_security_standards)
    error_message = "Pod Security Standards must be one of: privileged, baseline, restricted."
  }
}

variable "ingress_class" {
  description = "Ingress class to use"
  type        = string
  default     = "nginx"
}

variable "tls_enabled" {
  description = "Enable TLS for ingress"
  type        = bool
  default     = false
}

variable "cert_manager_enabled" {
  description = "Enable cert-manager for automatic TLS certificate management"
  type        = bool
  default     = false
}

variable "external_dns_enabled" {
  description = "Enable external-dns for automatic DNS management"
  type        = bool
  default     = false
}

# Environment-specific configurations
locals {
  environment_configs = {
    development = {
      replicas = {
        min = 1
        max = 2
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      autoscaling_enabled = false
      debug_logging       = true
      monitoring_enabled  = true
      backup_enabled      = false
    }
    
    staging = {
      replicas = {
        min = 2
        max = 4
      }
      resources = {
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
      autoscaling_enabled = true
      debug_logging       = false
      monitoring_enabled  = true
      backup_enabled      = true
    }
    
    production = {
      replicas = {
        min = 3
        max = 10
      }
      resources = {
        requests = {
          cpu    = "500m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "2000m"
          memory = "2Gi"
        }
      }
      autoscaling_enabled = true
      debug_logging       = false
      monitoring_enabled  = true
      backup_enabled      = true
    }
  }
}

# Outputs for use in other modules
output "environment_config" {
  description = "Environment-specific configuration"
  value       = local.environment_configs[var.environment]
}

output "cluster_domain" {
  description = "Cluster domain for internal services"
  value       = "cluster.local"
}

output "external_domain" {
  description = "External domain for public services"
  value       = var.domain_suffix
}