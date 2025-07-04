# terraform/monitoring.tf
# Monitoring infrastructure configuration

# Create monitoring namespace with labels
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = merge(local.common_labels, {
      component = "observability"
      name      = "monitoring"
    })
  }
  
  depends_on = [null_resource.minikube_cluster]
}

# ServiceMonitor for Tractus-X components
resource "kubernetes_manifest" "tractus_x_service_monitor" {
  count = var.enable_monitoring ? 1 : 0
  
  depends_on = [kubernetes_namespace.monitoring]
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "tractus-x-monitor"
      namespace = "monitoring"
      labels = {
        app = "tractus-x"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/part-of" = "tractus-x"
        }
      }
      namespaceSelector = {
        matchNames = ["tractus-x", "edc-standalone"]
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }
}

# Grafana ConfigMap for datasources
resource "kubernetes_config_map" "grafana_datasources" {
  count = var.enable_monitoring ? 1 : 0
  
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "datasources.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Prometheus"
          type      = "prometheus"
          url       = "http://prometheus-operated:9090"
          access    = "proxy"
          isDefault = true
        },
        {
          name   = "Loki"
          type   = "loki"
          url    = "http://loki:3100"
          access = "proxy"
        }
      ]
    })
  }
}

# Alert rules for Tractus-X
resource "kubernetes_config_map" "tractus_x_alerts" {
  count = var.enable_monitoring ? 1 : 0
  
  metadata {
    name      = "tractus-x-alerts"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      prometheus = "kube-prometheus"
    }
  }

  data = {
    "tractus-x-alerts.yaml" = <<-EOT
      groups:
        - name: tractus-x-critical
          rules:
            - alert: TractusXServiceDown
              expr: up{job=~"tractus-x.*"} == 0
              for: 1m
              labels:
                severity: critical
              annotations:
                summary: "Tractus-X service {{ $labels.instance }} is down"
                description: "Service {{ $labels.instance }} has been down for more than 1 minute"

            - alert: EDCConnectorDown
              expr: up{job="edc-controlplane"} == 0
              for: 30s
              labels:
                severity: critical
              annotations:
                summary: "EDC Connector is down"
                description: "EDC Control Plane {{ $labels.instance }} is not responding"

            - alert: PortalHighErrorRate
              expr: rate(http_requests_total{job="portal-backend",status=~"5.."}[5m]) > 0.05
              for: 2m
              labels:
                severity: high
              annotations:
                summary: "Portal backend high error rate"
                description: "Portal backend error rate is {{ $value }}% over 5 minutes"

            - alert: DatabaseConnectionHigh
              expr: pg_stat_activity_count > 80
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High database connections"
                description: "PostgreSQL has {{ $value }} active connections"
    EOT
  }
}

# Grafana dashboard configmap
resource "kubernetes_config_map" "grafana_dashboards_tractus_x" {
  count = var.enable_monitoring ? 1 : 0
  
  metadata {
    name      = "grafana-dashboard-tractus-x"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "tractus-x-overview.json" = jsonencode({
      dashboard = {
        id          = null
        title       = "Tractus-X Overview"
        tags        = ["tractus-x"]
        timezone    = "browser"
        refresh     = "30s"
        schemaVersion = 27
        version     = 1
        panels = [
          {
            id       = 1
            title    = "Service Status"
            type     = "stat"
            gridPos  = { h = 8, w = 12, x = 0, y = 0 }
            targets = [
              {
                expr         = "up{job=~\"tractus-x.*\"}"
                legendFormat = "{{ instance }}"
                refId        = "A"
              }
            ]
            fieldConfig = {
              defaults = {
                color = {
                  mode = "thresholds"
                }
                thresholds = {
                  steps = [
                    { color = "red", value = 0 },
                    { color = "green", value = 1 }
                  ]
                }
                mappings = [
                  { options = { "0" = { text = "Down" } }, type = "value" },
                  { options = { "1" = { text = "Up" } }, type = "value" }
                ]
              }
            }
          },
          {
            id      = 2
            title   = "Request Rate"
            type    = "graph"
            gridPos = { h = 8, w = 12, x = 12, y = 0 }
            targets = [
              {
                expr         = "sum(rate(http_requests_total{job=~\"tractus-x.*\"}[5m])) by (job)"
                legendFormat = "{{ job }}"
                refId        = "A"
              }
            ]
            yAxes = [
              {
                label = "Requests/sec"
                min   = 0
              }
            ]
          }
        ]
        time = {
          from = "now-1h"
          to   = "now"
        }
      }
    })
  }
}

# Prometheus recording rules
resource "kubernetes_config_map" "prometheus_recording_rules" {
  count = var.enable_monitoring ? 1 : 0
  
  metadata {
    name      = "prometheus-recording-rules"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      prometheus = "kube-prometheus"
    }
  }

  data = {
    "recording-rules.yaml" = <<-EOT
      groups:
        - name: tractus-x-recording-rules
          interval: 30s
          rules:
            - record: tractus_x:request_rate
              expr: sum(rate(http_requests_total{job=~"tractus-x.*"}[5m])) by (job, method, status)
            
            - record: tractus_x:error_rate
              expr: sum(rate(http_requests_total{job=~"tractus-x.*",status=~"5.."}[5m])) by (job) / sum(rate(http_requests_total{job=~"tractus-x.*"}[5m])) by (job)
            
            - record: tractus_x:response_time_p95
              expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=~"tractus-x.*"}[5m])) by (job, le))
            
            - record: tractus_x:cpu_usage
              expr: sum(rate(container_cpu_usage_seconds_total{namespace=~"tractus-x|edc-standalone"}[5m])) by (namespace, pod)
            
            - record: tractus_x:memory_usage
              expr: sum(container_memory_working_set_bytes{namespace=~"tractus-x|edc-standalone"}) by (namespace, pod)
    EOT
  }
}

# Monitoring namespace resource quota
resource "kubernetes_resource_quota" "monitoring_quota" {
  count = var.enable_monitoring ? 1 : 0
  
  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"           = var.resource_quotas.monitoring.cpu_requests
      "limits.cpu"             = var.resource_quotas.monitoring.cpu_limits
      "requests.memory"        = var.resource_quotas.monitoring.memory_requests
      "limits.memory"          = var.resource_quotas.monitoring.memory_limits
      "persistentvolumeclaims" = "10"
      "requests.storage"       = var.resource_quotas.monitoring.storage
    }
  }
}

# Output monitoring information
output "monitoring_namespace" {
  description = "Monitoring namespace name"
  value       = var.enable_monitoring ? kubernetes_namespace.monitoring.metadata[0].name : ""
}

output "grafana_url" {
  description = "Grafana URL"
  value       = var.enable_monitoring ? "http://grafana.${var.domain_suffix}" : ""
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = var.enable_monitoring ? "http://prometheus.${var.domain_suffix}" : ""
}