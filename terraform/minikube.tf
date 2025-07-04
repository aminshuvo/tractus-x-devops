# terraform/minikube.tf
# Minikube-specific configuration

# Minikube profile configuration
resource "null_resource" "minikube_config" {
  triggers = {
    cluster_name = var.cluster_name
    cpus         = local.resource_config[var.environment].cpus
    memory       = local.resource_config[var.environment].memory
    disk_size    = local.resource_config[var.environment].disk_size
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Configure Minikube settings
      minikube config set memory ${local.resource_config[var.environment].memory}
      minikube config set cpus ${local.resource_config[var.environment].cpus}
      minikube config set disk-size ${local.resource_config[var.environment].disk_size}
      minikube config set vm-driver ${var.minikube_driver}
    EOT
  }
}

# Enable required Minikube addons
resource "null_resource" "minikube_addons" {
  depends_on = [null_resource.minikube_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      minikube addons enable ingress --profile=${local.cluster_name}
      minikube addons enable ingress-dns --profile=${local.cluster_name}
      minikube addons enable storage-provisioner --profile=${local.cluster_name}
      minikube addons enable default-storageclass --profile=${local.cluster_name}
      minikube addons enable metrics-server --profile=${local.cluster_name}
    EOT
  }
}

# Configure Minikube tunnel for LoadBalancer services
resource "null_resource" "minikube_tunnel" {
  count = var.environment == "development" ? 1 : 0
  
  depends_on = [null_resource.minikube_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      # Start tunnel in background for LoadBalancer support
      nohup minikube tunnel --profile=${local.cluster_name} > /tmp/minikube-tunnel.log 2>&1 &
      echo $! > /tmp/minikube-tunnel.pid
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      if [ -f /tmp/minikube-tunnel.pid ]; then
        kill $(cat /tmp/minikube-tunnel.pid) || true
        rm -f /tmp/minikube-tunnel.pid
      fi
    EOT
  }
}

# Minikube cluster resource quotas
resource "kubernetes_resource_quota" "tractus_x_quota" {
  metadata {
    name      = "tractus-x-quota"
    namespace = kubernetes_namespace.tractus_x.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quotas.tractus_x.cpu_requests
      "limits.cpu"      = var.resource_quotas.tractus_x.cpu_limits
      "requests.memory" = var.resource_quotas.tractus_x.memory_requests
      "limits.memory"   = var.resource_quotas.tractus_x.memory_limits
      "persistentvolumeclaims" = "10"
      "requests.storage" = var.resource_quotas.tractus_x.storage
    }
  }
}

resource "kubernetes_resource_quota" "edc_standalone_quota" {
  metadata {
    name      = "edc-standalone-quota"
    namespace = kubernetes_namespace.edc_standalone.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quotas.edc_standalone.cpu_requests
      "limits.cpu"      = var.resource_quotas.edc_standalone.cpu_limits
      "requests.memory" = var.resource_quotas.edc_standalone.memory_requests
      "limits.memory"   = var.resource_quotas.edc_standalone.memory_limits
      "persistentvolumeclaims" = "5"
      "requests.storage" = var.resource_quotas.edc_standalone.storage
    }
  }
}

resource "kubernetes_resource_quota" "monitoring_quota" {
  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quotas.monitoring.cpu_requests
      "limits.cpu"      = var.resource_quotas.monitoring.cpu_limits
      "requests.memory" = var.resource_quotas.monitoring.memory_requests
      "limits.memory"   = var.resource_quotas.monitoring.memory_limits
      "persistentvolumeclaims" = "5"
      "requests.storage" = var.resource_quotas.monitoring.storage
    }
  }
}

# Minikube specific ingress configuration
resource "kubernetes_config_map" "ingress_config" {
  metadata {
    name      = "nginx-configuration"
    namespace = "ingress-nginx"
  }

  data = {
    "proxy-connect-timeout" = "15"
    "proxy-send-timeout"    = "600"
    "proxy-read-timeout"    = "600"
    "body-size"            = "64m"
    "hsts-max-age"         = "31536000"
    "hsts-include-subdomains" = "true"
    "server-name-hash-bucket-size" = "256"
  }

  depends_on = [null_resource.minikube_addons]
}