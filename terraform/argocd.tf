# terraform/argocd.tf
# ArgoCD-specific configuration

# ArgoCD CLI configuration
resource "null_resource" "argocd_config" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for ArgoCD to be ready
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
      
      # Get ArgoCD admin password
      ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
      
      # Save configuration
      mkdir -p ~/.argocd
      echo "contexts:
        argocd.${var.domain_suffix}:
          server: argocd.${var.domain_suffix}
          insecure: true
          username: admin
      current-context: argocd.${var.domain_suffix}" > ~/.argocd/config
      
      echo "ArgoCD configured successfully"
      echo "Admin password: $ARGOCD_PASSWORD"
    EOT
  }
}

# ArgoCD application projects
resource "kubernetes_manifest" "argocd_projects" {
  depends_on = [helm_release.argocd]
  
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "tractus-x"
      namespace = "argocd"
    }
    spec = {
      description = "Tractus-X Automotive Dataspace Project"
      sourceRepos = [
        "https://eclipse-tractusx.github.io/charts/dev",
        "https://eclipse-tractusx.github.io/charts/stable",
        "https://github.com/aminshuvo/tractus-x-devops",
        "*"
      ]
      destinations = [
        {
          namespace = "tractus-x"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "edc-standalone"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "monitoring"
          server    = "https://kubernetes.default.svc"
        }
      ]
      clusterResourceWhitelist = [
        {
          group = ""
          kind  = "Namespace"
        },
        {
          group = "storage.k8s.io"
          kind  = "StorageClass"
        },
        {
          group = "networking.k8s.io"
          kind  = "IngressClass"
        },
        {
          group = "rbac.authorization.k8s.io"
          kind  = "ClusterRole"
        },
        {
          group = "rbac.authorization.k8s.io"
          kind  = "ClusterRoleBinding"
        }
      ]
      namespaceResourceWhitelist = [
        {
          group = ""
          kind  = "*"
        },
        {
          group = "apps"
          kind  = "*"
        },
        {
          group = "extensions"
          kind  = "*"
        },
        {
          group = "networking.k8s.io"
          kind  = "*"
        },
        {
          group = "policy"
          kind  = "*"
        },
        {
          group = "rbac.authorization.k8s.io"
          kind  = "*"
        },
        {
          group = "autoscaling"
          kind  = "*"
        },
        {
          group = "batch"
          kind  = "*"
        }
      ]
      roles = [
        {
          name        = "admin"
          description = "Full access to Tractus-X applications"
          policies = [
            "p, proj:tractus-x:admin, applications, *, tractus-x/*, allow",
            "p, proj:tractus-x:admin, repositories, *, *, allow",
            "p, proj:tractus-x:admin, certificates, *, *, allow"
          ]
          groups = ["tractus-x:admin"]
        },
        {
          name        = "developer"
          description = "Developer access to Tractus-X applications"
          policies = [
            "p, proj:tractus-x:developer, applications, get, tractus-x/*, allow",
            "p, proj:tractus-x:developer, applications, sync, tractus-x/*, allow",
            "p, proj:tractus-x:developer, repositories, get, *, allow"
          ]
          groups = ["tractus-x:developer"]
        },
        {
          name        = "readonly"
          description = "Read-only access to Tractus-X applications"
          policies = [
            "p, proj:tractus-x:readonly, applications, get, tractus-x/*, allow",
            "p, proj:tractus-x:readonly, repositories, get, *, allow"
          ]
          groups = ["tractus-x:readonly"]
        }
      ]
    }
  }
}

# ArgoCD RBAC configuration
resource "kubernetes_config_map" "argocd_rbac_config" {
  metadata {
    name      = "argocd-rbac-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-rbac-cm"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "policy.default" = "role:readonly"
    "policy.csv" = <<-EOT
      # ArgoCD RBAC Policy
      p, role:admin, applications, *, */*, allow
      p, role:admin, clusters, *, *, allow
      p, role:admin, repositories, *, *, allow
      
      p, role:developer, applications, get, */*, allow
      p, role:developer, applications, sync, */*, allow
      p, role:developer, applications, action/*, */*, allow
      p, role:developer, logs, get, */*, allow
      p, role:developer, exec, create, */*, allow
      
      p, role:readonly, applications, get, */*, allow
      p, role:readonly, logs, get, */*, allow
      p, role:readonly, clusters, get, *, allow
      p, role:readonly, repositories, get, *, allow
      
      # Groups
      g, tractus-x:admin, role:admin
      g, tractus-x:developer, role:developer
      g, tractus-x:readonly, role:readonly
    EOT
  }

  depends_on = [helm_release.argocd]
}

# ArgoCD server configuration
resource "kubernetes_config_map" "argocd_cmd_params" {
  metadata {
    name      = "argocd-cmd-params-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-cmd-params-cm"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "server.insecure"                    = var.environment != "production" ? "true" : "false"
    "server.disable.auth"                = "false"
    "server.enable.grpc.web"             = "true"
    "controller.status.processors"       = "20"
    "controller.operation.processors"    = "10"
    "controller.self.heal.timeout.seconds" = "5"
    "controller.repo.server.timeout.seconds" = "60"
    "reposerver.parallelism.limit"       = "10"
  }

  depends_on = [helm_release.argocd]
}

# ArgoCD repository secret for private repositories
resource "kubernetes_secret" "argocd_repo_secret" {
  metadata {
    name      = "tractus-x-repo"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type = "git"
    url  = "https://github.com/aminshuvo/tractus-x-devops"
    # For private repositories, add:
    # username = ""
    # password = ""
    # sshPrivateKey = ""
  }

  depends_on = [helm_release.argocd]
}

# Output ArgoCD information
output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = "Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = false
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "https://argocd.${var.domain_suffix}"
}