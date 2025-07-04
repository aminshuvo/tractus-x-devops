# terraform/main.tf
terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Local variables for configuration
locals {
  cluster_name = var.cluster_name
  environment  = var.environment
  
  # Resource allocation based on environment
  resource_config = {
    development = {
      cpus      = 4
      memory    = "8192"
      disk_size = "40g"
      nodes     = 1
    }
    staging = {
      cpus      = 6
      memory    = "12288"
      disk_size = "60g"
      nodes     = 2
    }
    production = {
      cpus      = 8
      memory    = "16384"
      disk_size = "100g"
      nodes     = 3
    }
  }
  
  # Common labels
  common_labels = {
    environment = var.environment
    project     = "tractus-x"
    managed_by  = "terraform"
  }
}

# Minikube cluster setup
resource "null_resource" "minikube_cluster" {
  triggers = {
    cluster_name = local.cluster_name
    environment  = var.environment
    cpus         = local.resource_config[var.environment].cpus
    memory       = local.resource_config[var.environment].memory
    disk_size    = local.resource_config[var.environment].disk_size
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      # Check if cluster exists
      if minikube profile list -o json | jq -r '.valid[].Name' | grep -q "^${local.cluster_name}$"; then
        echo "Cluster ${local.cluster_name} already exists"
        minikube profile ${local.cluster_name}
      else
        echo "Creating new Minikube cluster: ${local.cluster_name}"
        minikube start \
          --profile=${local.cluster_name} \
          --cpus=${local.resource_config[var.environment].cpus} \
          --memory=${local.resource_config[var.environment].memory} \
          --disk-size=${local.resource_config[var.environment].disk_size} \
          --kubernetes-version=${var.kubernetes_version} \
          --driver=${var.minikube_driver} \
          --container-runtime=containerd \
          --feature-gates="GracefulNodeShutdown=true" \
          --addons=ingress,ingress-dns,storage-provisioner,default-storageclass,metrics-server
      fi
      
      # Wait for cluster to be ready
      kubectl --context=${local.cluster_name} wait --for=condition=Ready nodes --all --timeout=300s
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      minikube delete --profile=${self.triggers.cluster_name} || true
    EOT
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = local.cluster_name
  
  depends_on = [null_resource.minikube_cluster]
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = local.cluster_name
  }
  
  depends_on = [null_resource.minikube_cluster]
}

# Create namespaces
resource "kubernetes_namespace" "tractus_x" {
  metadata {
    name = "tractus-x"
    labels = merge(local.common_labels, {
      component = "tractus-x-umbrella"
    })
  }
  
  depends_on = [null_resource.minikube_cluster]
}

resource "kubernetes_namespace" "edc_standalone" {
  metadata {
    name = "edc-standalone"
    labels = merge(local.common_labels, {
      component = "edc-standalone"
    })
  }
  
  depends_on = [null_resource.minikube_cluster]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = merge(local.common_labels, {
      component = "observability"
    })
  }
  
  depends_on = [null_resource.minikube_cluster]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = merge(local.common_labels, {
      component = "gitops"
    })
  }
  
  depends_on = [null_resource.minikube_cluster]
}

# Install ArgoCD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_version

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.domain_suffix}"
      }
      
      configs = {
        params = {
          "server.insecure" = var.environment != "production"
        }
      }
      
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = true
          ingressClassName = "nginx"
          hosts = ["argocd.${var.domain_suffix}"]
          tls = var.environment == "production" ? [{
            secretName = "argocd-tls"
            hosts = ["argocd.${var.domain_suffix}"]
          }] : []
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      
      controller = {
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }
      
      repoServer = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# Install Sealed Secrets Controller
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = "kube-system"
  version    = var.sealed_secrets_version

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }

  depends_on = [null_resource.minikube_cluster]
}

# Create storage class for fast SSD storage
resource "kubernetes_storage_class" "fast_ssd" {
  metadata {
    name = "fast-ssd"
    labels = local.common_labels
  }
  
  storage_provisioner = "k8s.io/minikube-hostpath"
  parameters = {
    type = "pd-ssd"
  }
  
  volume_binding_mode = "WaitForFirstConsumer"
  
  depends_on = [null_resource.minikube_cluster]
}

# Network policies for security
resource "kubernetes_network_policy" "tractus_x_isolation" {
  metadata {
    name      = "tractus-x-isolation"
    namespace = kubernetes_namespace.tractus_x.metadata[0].name
  }

  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "tractus-x"
          }
        }
      }
      
      from {
        namespace_selector {
          match_labels = {
            name = "edc-standalone"
          }
        }
      }
      
      from {
        namespace_selector {
          match_labels = {
            name = "monitoring"
          }
        }
      }
    }
    
    egress {
      to {}
    }
  }
  
  depends_on = [kubernetes_namespace.tractus_x]
}

# DNS configuration for local development
resource "null_resource" "dns_setup" {
  count = var.environment == "development" ? 1 : 0
  
  triggers = {
    cluster_name = local.cluster_name
    domain_suffix = var.domain_suffix
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      MINIKUBE_IP=$(minikube ip --profile=${local.cluster_name})
      
      # Update /etc/hosts for local development
      sudo tee -a /etc/hosts <<EOF

# Tractus-X Development Environment - Managed by Terraform
$MINIKUBE_IP argocd.${var.domain_suffix}
$MINIKUBE_IP portal.${var.domain_suffix}
$MINIKUBE_IP centralidp.${var.domain_suffix}
$MINIKUBE_IP dataconsumer.${var.domain_suffix}
$MINIKUBE_IP dataprovider.${var.domain_suffix}
$MINIKUBE_IP grafana.${var.domain_suffix}
$MINIKUBE_IP prometheus.${var.domain_suffix}
$MINIKUBE_IP loki.${var.domain_suffix}
$MINIKUBE_IP edc-consumer.${var.domain_suffix}
$MINIKUBE_IP edc-provider.${var.domain_suffix}
EOF
    EOT
  }

  depends_on = [null_resource.minikube_cluster]
}

# Output important information
output "cluster_name" {
  description = "Name of the Minikube cluster"
  value       = local.cluster_name
}

output "cluster_ip" {
  description = "IP address of the Minikube cluster"
  value       = data.external.minikube_ip.result.ip
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://argocd.${var.domain_suffix}"
}

output "kubeconfig_context" {
  description = "Kubectl context for the cluster"
  value       = local.cluster_name
}

# Get Minikube IP
data "external" "minikube_ip" {
  program = ["bash", "-c", "echo '{\"ip\":\"'$(minikube ip --profile=${local.cluster_name})'\"}'"]
  
  depends_on = [null_resource.minikube_cluster]
}