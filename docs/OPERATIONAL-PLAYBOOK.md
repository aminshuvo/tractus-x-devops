# Operational Playbook

This document provides operational guidance for managing the Tractus-X deployment in production environments.

## Production Architecture

### High Availability Setup

For production deployments, consider:

- Multi-node Kubernetes cluster (minimum 3 nodes)
- Load balancing across multiple EDC instances
- Database clustering for persistent storage
- Backup and disaster recovery procedures
- Geographic distribution across multiple regions
- Auto-scaling capabilities

### Resource Requirements

**Production Minimum:**
- CPU: 16 cores total across cluster
- RAM: 32 GB total across cluster
- Storage: 100 GB persistent storage
- Network: High-speed networking with redundancy

**Production Recommended:**
- CPU: 32+ cores total
- RAM: 64+ GB total
- Storage: 500+ GB persistent storage with backup
- Network: Multi-zone networking with failover

### Infrastructure Components

```
Production Architecture:
┌─────────────────────────────────────────────────────────┐
│                    Load Balancer                        │
│                  (Cloud Provider LB)                    │
└─────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │   Master    │ │   Master    │ │     Master      │    │
│  │   Node 1    │ │   Node 2    │ │     Node 3      │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │   Worker    │ │   Worker    │ │     Worker      │    │
│  │   Node 1    │ │   Node 2    │ │     Node 3      │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
└─────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────┐
│               External Dependencies                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │  Database   │ │   Storage   │ │   Monitoring    │    │
│  │  Cluster    │ │   Cluster   │ │    Stack        │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Kubernetes Cluster Health**
   - Node availability and resource usage
   - Pod restart rates and failure counts
   - Persistent volume usage and I/O performance
   - Network latency and throughput
   - Certificate expiration dates

2. **EDC Connector Performance**
   - Contract negotiation success rates
   - Data transfer completion rates and throughput
   - API response times and error rates
   - Queue depths and processing times
   - Authentication and authorization failures

3. **Tractus-X Services**
   - Portal availability and response times
   - IAM service authentication success rates
   - Discovery service catalog updates and sync status
   - Database connection pool utilization
   - Cache hit rates and performance

4. **Infrastructure Metrics**
   - CPU, memory, disk, and network utilization
   - Database performance metrics
   - Load balancer health and distribution
   - DNS resolution times
   - SSL certificate status

### Alert Configuration

#### Critical Alerts (Immediate Response Required)

```yaml
# Pod crash loops (>3 restarts in 15 minutes)
- alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.2
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Pod {{ $labels.pod }} is crash looping"
    description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"
    runbook_url: "https://runbooks.tractus-x.org/pod-crash-looping"

# High resource usage (>90% CPU/memory for >10 minutes)
- alert: HighResourceUsage
  expr: (container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 0.9
  for: 10m
  labels:
    severity: critical
  annotations:
    summary: "High memory usage in {{ $labels.pod }}"
    description: "Container {{ $labels.container }} in pod {{ $labels.pod }} is using more than 90% of its memory limit"

# EDC connector failures (health check failures >5 minutes)
- alert: EDCConnectorDown
  expr: up{job="tractus-x-edc"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "EDC Connector is down"
    description: "EDC Connector {{ $labels.instance }} has been down for more than 5 minutes"

# Certificate expiration warnings (30 days before expiry)
- alert: CertificateExpiringSoon
  expr: probe_ssl_earliest_cert_expiry - time() < 30 * 24 * 3600
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "Certificate expiring soon"
    description: "Certificate for {{ $labels.instance }} expires in less than 30 days"
```

#### Warning Alerts (Response Required Within Hours)

```yaml
# High error rates (>5% for >15 minutes)
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "High error rate for {{ $labels.service }}"
    description: "Service {{ $labels.service }} has an error rate above 5%"

# Slow response times (>2s average for >10 minutes)
- alert: SlowResponseTimes
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Slow response times for {{ $labels.service }}"
    description: "95th percentile response time for {{ $labels.service }} is above 2 seconds"

# Disk space usage (>80% for >5 minutes)
- alert: HighDiskUsage
  expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes > 0.8
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High disk usage on {{ $labels.instance }}"
    description: "Disk usage on {{ $labels.instance }} is above 80%"
```

### Alerting Channels

Configure multiple alerting channels for different severity levels:

```yaml
# PagerDuty for critical alerts
- name: pagerduty-critical
  pagerduty_configs:
  - routing_key: <pagerduty-integration-key>
    severity: critical
    client: "Tractus-X Monitoring"
    client_url: "https://grafana.tractus-x.org"

# Slack for warnings
- name: slack-warnings
  slack_configs:
  - api_url: <slack-webhook-url>
    channel: '#tractus-x-alerts'
    title: 'Tractus-X Alert'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

# Email for all alerts
- name: email-alerts
  email_configs:
  - to: 'platform-team@tractus-x.org'
    from: 'alerts@tractus-x.org'
    subject: 'Tractus-X Alert: {{ .GroupLabels.alertname }}'
    body: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Backup and Recovery

### Backup Strategy

#### 1. Database Backups

```bash
# Automated daily backup script
#!/bin/bash
# scripts/backup-database.sh

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/database/$BACKUP_DATE"
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL databases
kubectl exec -n tractus-x deployment/postgresql -- pg_dumpall -U postgres > "$BACKUP_DIR/postgresql_all.sql"

# Backup individual databases
for db in tractus_x edc_control edc_data; do
    kubectl exec -n tractus-x deployment/postgresql -- pg_dump -U postgres -d "$db" > "$BACKUP_DIR/${db}.sql"
done

# Compress backup
tar -czf "$BACKUP_DIR.tar.gz" -C /backups/database "$(basename $BACKUP_DIR)"
rm -rf "$BACKUP_DIR"

# Upload to cloud storage
aws s3 cp "$BACKUP_DIR.tar.gz" s3://tractus-x-backups/database/

# Cleanup old backups
find /backups/database -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
aws s3 ls s3://tractus-x-backups/database/ | awk '$1 <= "'$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)'"' | awk '{print $4}' | xargs -I {} aws s3 rm s3://tractus-x-backups/database/{}
```

#### 2. Configuration Backups

```bash
# Configuration backup script
#!/bin/bash
# scripts/backup-config.sh

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/config/$BACKUP_DATE"

mkdir -p "$BACKUP_DIR"

# Backup Kubernetes resources
kubectl get all -A -o yaml > "$BACKUP_DIR/all-resources.yaml"
kubectl get configmaps -A -o yaml > "$BACKUP_DIR/configmaps.yaml"
kubectl get secrets -A -o yaml > "$BACKUP_DIR/secrets.yaml"
kubectl get pv,pvc -A -o yaml > "$BACKUP_DIR/storage.yaml"
kubectl get ingress -A -o yaml > "$BACKUP_DIR/ingress.yaml"

# Backup ArgoCD applications
kubectl get applications -n argocd -o yaml > "$BACKUP_DIR/argocd-applications.yaml"
kubectl get appprojects -n argocd -o yaml > "$BACKUP_DIR/argocd-projects.yaml"

# Backup custom resources
kubectl get crds -o yaml > "$BACKUP_DIR/crds.yaml"

# Backup Helm releases
helm list -A -o yaml > "$BACKUP_DIR/helm-releases.yaml"

# Compress and upload
tar -czf "$BACKUP_DIR.tar.gz" -C /backups/config "$(basename $BACKUP_DIR)"
rm -rf "$BACKUP_DIR"
aws s3 cp "$BACKUP_DIR.tar.gz" s3://tractus-x-backups/config/
```

#### 3. Certificate Management

```bash
# Certificate backup and renewal
#!/bin/bash
# scripts/backup-certificates.sh

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/certificates/$BACKUP_DATE"

mkdir -p "$BACKUP_DIR"

# Backup TLS secrets
kubectl get secrets -A -l type=kubernetes.io/tls -o yaml > "$BACKUP_DIR/tls-secrets.yaml"

# Check certificate expiration
kubectl get secrets -A -l type=kubernetes.io/tls -o json | jq -r '.items[] | select(.data."tls.crt") | "\(.metadata.namespace)/\(.metadata.name): \(.data."tls.crt")"' | while read line; do
    namespace_secret=$(echo "$line" | cut -d: -f1)
    cert_data=$(echo "$line" | cut -d: -f2)
    expiry=$(echo "$cert_data" | base64 -d | openssl x509 -noout -enddate | cut -d= -f2)
    echo "$namespace_secret expires on $expiry"
done > "$BACKUP_DIR/certificate-expiry.txt"

# Compress and upload
tar -czf "$BACKUP_DIR.tar.gz" -C /backups/certificates "$(basename $BACKUP_DIR)"
rm -rf "$BACKUP_DIR"
aws s3 cp "$BACKUP_DIR.tar.gz" s3://tractus-x-backups/certificates/
```

### Disaster Recovery

#### Recovery Time Objectives (RTO)

- **Critical services**: 30 minutes
- **Non-critical services**: 2 hours
- **Full system restore**: 4 hours
- **Data consistency check**: 1 hour

#### Recovery Point Objectives (RPO)

- **Database**: 1 hour (last backup)
- **Configuration**: Real-time (GitOps)
- **Logs**: 15 minutes (buffer time)
- **Metrics**: 5 minutes (scrape interval)

#### Disaster Recovery Procedures

1. **Assess the Situation**
   ```bash
   # Check cluster status
   kubectl cluster-info
   kubectl get nodes
   kubectl get pods -A | grep -v Running
   
   # Check critical services
   curl -f https://tractus-x.example.com/health
   curl -f https://argocd.example.com/api/version
   ```

2. **Activate DR Plan**
   ```bash
   # Switch to DR cluster
   kubectl config use-context dr-cluster
   
   # Restore from backup
   ./scripts/restore-full-system.sh
   
   # Update DNS to point to DR cluster
   aws route53 change-resource-record-sets --hosted-zone-id Z123456789 --change-batch file://dns-change.json
   ```

3. **Verify Recovery**
   ```bash
   # Run health checks
   ./scripts/health-check.sh
   
   # Run integration tests
   pytest tests/integration/ -v
   
   # Verify data integrity
   ./scripts/data-integrity-check.sh
   ```

## Security

### Access Control

#### 1. Kubernetes RBAC

```yaml
# Role for platform team
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

---
# Role for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: tractus-x
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch"]

---
# Role for read-only access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list"]
- apiGroups: ["apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list"]
```

#### 2. Network Policies

```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: tractus-x
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow ingress traffic to portal
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-portal-ingress
  namespace: tractus-x
spec:
  podSelector:
    matchLabels:
      app: portal
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080

---
# Allow EDC inter-connector communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-edc-communication
  namespace: tractus-x
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: edc
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: edc-standalone
    - podSelector:
        matchLabels:
          app.kubernetes.io/component: edc
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8181
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: edc-standalone
    - podSelector:
        matchLabels:
          app.kubernetes.io/component: edc
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8181
```

#### 3. EDC Security Configuration

```yaml
# EDC security configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: edc-security-config
  namespace: tractus-x
data:
  security.properties: |
    # JWT Configuration
    edc.oauth.token.url=https://iam.tractus-x.org/token
    edc.oauth.client.id=${EDC_CLIENT_ID}
    edc.oauth.client.secret=${EDC_CLIENT_SECRET}
    
    # TLS Configuration
    edc.web.https.port=8443
    edc.web.https.path=/api
    edc.web.https.keystore.path=/etc/ssl/certs/keystore.p12
    edc.web.https.keystore.password=${KEYSTORE_PASSWORD}
    
    # Data Plane Security
    edc.dataplane.token.validation.endpoint=https://iam.tractus-x.org/validate
    
    # Connector Identity
    edc.participant.id=${PARTICIPANT_ID}
    edc.connector.name=${CONNECTOR_NAME}
```

### Certificate Management

#### Automated Certificate Renewal with cert-manager

```yaml
# cert-manager ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: certificates@tractus-x.org
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx

---
# Certificate for main domain
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tractus-x-tls
  namespace: tractus-x
spec:
  secretName: tractus-x-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - tractus-x.example.com
  - api.tractus-x.example.com
```

#### Certificate Monitoring

```bash
# Certificate monitoring script
#!/bin/bash
# scripts/monitor-certificates.sh

# Check all TLS certificates
kubectl get certificates -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[] | select(.type=="Ready") | .status)"' | while read line; do
    cert_status=$(echo "$line" | cut -d: -f2 | tr -d ' ')
    if [ "$cert_status" != "True" ]; then
        echo "Certificate issue: $line"
        # Send alert
        curl -X POST -H 'Content-type: application/json' \
             --data '{"text":"Certificate issue: '"$line"'"}' \
             $SLACK_WEBHOOK_URL
    fi
done

# Check certificate expiration
kubectl get secrets -A -l type=kubernetes.io/tls -o json | jq -r '.items[] | select(.data."tls.crt") | "\(.metadata.namespace)/\(.metadata.name): \(.data."tls.crt")"' | while read line; do
    namespace_secret=$(echo "$line" | cut -d: -f1)
    cert_data=$(echo "$line" | cut -d: -f2)
    
    # Calculate days until expiration
    expiry_epoch=$(echo "$cert_data" | base64 -d | openssl x509 -noout -enddate | cut -d= -f2 | xargs -I {} date -d "{}" +%s)
    current_epoch=$(date +%s)
    days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ $days_until_expiry -lt 30 ]; then
        echo "Certificate $namespace_secret expires in $days_until_expiry days"
        # Send alert for certificates expiring in <30 days
        curl -X POST -H 'Content-type: application/json' \
             --data '{"text":"Certificate '"$namespace_secret"' expires in '"$days_until_expiry"' days"}' \
             $SLACK_WEBHOOK_URL
    fi
done
```

## Scaling

### Horizontal Scaling

#### Services That Can Be Horizontally Scaled

1. **EDC Control Plane (Stateless Components)**
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: edc-control-plane-hpa
     namespace: tractus-x
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: edc-control-plane
     minReplicas: 2
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
     - type: Resource
       resource:
         name: memory
         target:
           type: Utilization
           averageUtilization: 80
     behavior:
       scaleUp:
         stabilizationWindowSeconds: 300
         policies:
         - type: Percent
           value: 100
           periodSeconds: 15
       scaleDown:
         stabilizationWindowSeconds: 300
         policies:
         - type: Percent
           value: 50
           periodSeconds: 60
   ```

2. **Tractus-X Portal (Web Tier)**
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: portal-hpa
     namespace: tractus-x
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: portal
     minReplicas: 3
     maxReplicas: 20
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 60
     - type: Pods
       pods:
         metric:
           name: http_requests_per_second
         target:
           type: AverageValue
           averageValue: "100"
   ```

3. **Monitoring Components**
   ```yaml
   # Prometheus with sharding
   apiVersion: monitoring.coreos.com/v1
   kind: Prometheus
   metadata:
     name: prometheus-sharded
     namespace: monitoring
   spec:
     replicas: 3
     shards: 2
     retention: 30d
     resources:
       requests:
         memory: 2Gi
         cpu: 1000m
       limits:
         memory: 4Gi
         cpu: 2000m
   ```

### Vertical Scaling

#### Components That Benefit from Vertical Scaling

1. **Database Instances**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: postgresql
     namespace: tractus-x
   spec:
     template:
       spec:
         containers:
         - name: postgresql
           resources:
             requests:
               memory: 4Gi
               cpu: 2000m
             limits:
               memory: 8Gi
               cpu: 4000m
   ```

2. **In-Memory Caches (Redis)**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: redis
     namespace: tractus-x
   spec:
     template:
       spec:
         containers:
         - name: redis
           resources:
             requests:
               memory: 2Gi
               cpu: 500m
             limits:
               memory: 4Gi
               cpu: 1000m
   ```

### Custom Metrics Auto-scaling

```yaml
# Custom metrics HPA using Prometheus adapter
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: edc-custom-metrics-hpa
  namespace: tractus-x
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: edc-control-plane
  minReplicas: 2
  maxReplicas: 15
  metrics:
  - type: Pods
    pods:
      metric:
        name: contract_negotiations_per_second
      target:
        type: AverageValue
        averageValue: "10"
  - type: Pods
    pods:
      metric:
        name: queue_depth
      target:
        type: AverageValue
        averageValue: "50"
```

## Maintenance

### Regular Maintenance Tasks

#### Daily Tasks

```bash
#!/bin/bash
# scripts/daily-maintenance.sh

echo "=== Daily Maintenance - $(date) ==="

# 1. Monitor system health dashboards
echo "Checking system health..."
curl -s https://grafana.tractus-x.org/api/health || echo "Grafana unhealthy"
curl -s https://prometheus.tractus-x.org/api/v1/query?query=up | jq '.data.result | length' || echo "Prometheus query failed"

# 2. Review alert notifications
echo "Checking active alerts..."
alerts=$(curl -s https://prometheus.tractus-x.org/api/v1/alerts | jq '.data.alerts | length')
echo "Active alerts: $alerts"

# 3. Check backup completion status
echo "Checking backup status..."
backup_status=$(kubectl get cronjobs -n tractus-x backup-database -o jsonpath='{.status.lastSuccessfulTime}')
echo "Last successful backup: $backup_status"

# 4. Verify certificate status
echo "Checking certificate expiration..."
./scripts/monitor-certificates.sh

# 5. Check resource usage
echo "Resource usage summary:"
kubectl top nodes
kubectl top pods -A --sort-by=cpu | head -10

# 6. Review pod restart counts
echo "Pods with recent restarts:"
kubectl get pods -A --field-selector=status.phase=Running -o json | jq -r '.items[] | select(.status.containerStatuses[]?.restartCount > 0) | "\(.metadata.namespace)/\(.metadata.name): \(.status.containerStatuses[0].restartCount) restarts"'

echo "=== Daily Maintenance Complete ==="
```

#### Weekly Tasks

```bash
#!/bin/bash
# scripts/weekly-maintenance.sh

echo "=== Weekly Maintenance - $(date) ==="

# 1. Review resource usage trends
echo "Generating resource usage report..."
kubectl top nodes > /tmp/node-usage-$(date +%Y%m%d).txt
kubectl top pods -A > /tmp/pod-usage-$(date +%Y%m%d).txt

# 2. Update security patches
echo "Checking for security updates..."
# Update base images
docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "(ubuntu|alpine|debian)" | while read image; do
    echo "Checking updates for $image"
    docker pull "$image" || echo "Failed to update $image"
done

# 3. Test backup recovery procedures
echo "Testing backup recovery..."
./scripts/test-backup-recovery.sh

# 4. Review and rotate secrets
echo "Checking secret rotation status..."
kubectl get secrets -A -o json | jq -r '.items[] | select(.metadata.creationTimestamp < "'$(date -d '90 days ago' --iso-8601)'") | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.creationTimestamp)"'

# 5. Update monitoring dashboards
echo "Updating Grafana dashboards..."
curl -X POST -H "Content-Type: application/json" -d @configs/grafana/dashboards/updated-dashboard.json \
     https://admin:${GRAFANA_PASSWORD}@grafana.tractus-x.org/api/dashboards/db

# 6. Performance optimization review
echo "Running performance analysis..."
kubectl exec -n monitoring deployment/prometheus -- promtool query instant 'rate(container_cpu_usage_seconds_total[1h])' > /tmp/cpu-analysis-$(date +%Y%m%d).txt

echo "=== Weekly Maintenance Complete ==="
```

#### Monthly Tasks

```bash
#!/bin/bash
# scripts/monthly-maintenance.sh

echo "=== Monthly Maintenance - $(date) ==="

# 1. Capacity planning review
echo "Generating capacity planning report..."
./scripts/capacity-planning-report.sh > /reports/capacity-$(date +%Y%m).txt

# 2. Security audit and compliance check
echo "Running security audit..."
kubectl auth can-i --list --as=system:serviceaccount:default:default > /tmp/rbac-audit-$(date +%Y%m%d).txt
kubectl get networkpolicies -A -o yaml > /tmp/network-policies-$(date +%Y%m%d).yaml

# 3. Performance optimization review
echo "Analyzing performance trends..."
kubectl exec -n monitoring deployment/prometheus -- promtool query range \
    --start=$(date -d '30 days ago' --iso-8601) \
    --end=$(date --iso-8601) \
    --step=1h \
    'rate(http_request_duration_seconds_sum[5m])' > /tmp/performance-trends-$(date +%Y%m).txt

# 4. Disaster recovery test
echo "Scheduling DR test..."
./scripts/schedule-dr-test.sh

# 5. Update documentation
echo "Checking documentation currency..."
find docs/ -name "*.md" -mtime +60 -exec echo "Document may need update: {}" \;

# 6. License compliance check
echo "Checking license compliance..."
kubectl get pods -A -o json | jq -r '.items[].spec.containers[].image' | sort -u > /tmp/images-$(date +%Y%m%d).txt

echo "=== Monthly Maintenance Complete ==="
```

### Update Procedures

#### 1. Infrastructure Updates

```bash
#!/bin/bash
# scripts/update-infrastructure.sh

echo "Starting infrastructure update..."

# 1. Backup current state
kubectl get all -A -o yaml > backups/pre-update-$(date +%Y%m%d).yaml

# 2. Update Terraform configuration
cd terraform
terraform plan -out=update.tfplan
terraform apply update.tfplan

# 3. Update Kubernetes cluster (if using managed service)
# For GKE:
# gcloud container clusters upgrade tractus-x-cluster --cluster-version=1.28.0

# For EKS:
# eksctl update cluster --name tractus-x-cluster --version 1.28

# 4. Update node pools
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
# Replace node or update node pool
kubectl uncordon <node-name>

# 5. Verify cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running | grep -v Completed

echo "Infrastructure update complete"
```

#### 2. Application Updates

```bash
#!/bin/bash
# scripts/update-applications.sh

echo "Starting application updates..."

# 1. Update Helm repositories
helm repo update

# 2. Check for available updates
helm list -A -o json | jq -r '.[] | "\(.name) \(.namespace) \(.chart) \(.app_version)"' | while read name namespace chart version; do
    echo "Checking updates for $name in $namespace..."
    latest=$(helm search repo $(echo $chart | cut -d- -f1) --version ">$version" -o json | jq -r '.[0].version // empty')
    if [ ! -z "$latest" ]; then
        echo "Update available: $chart $version -> $latest"
    fi
done

# 3. Perform canary deployments for critical services
kubectl patch deployment -n tractus-x edc-control-plane -p='{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":"25%","maxSurge":"25%"}}}}'

# 4. Update applications via ArgoCD
argocd app sync tractus-x-umbrella --strategy hook

# 5. Monitor rollout
kubectl rollout status -n tractus-x deployment/edc-control-plane --timeout=600s

# 6. Run health checks
./scripts/health-check.sh

echo "Application updates complete"
```

#### 3. Security Updates

```bash
#!/bin/bash
# scripts/security-updates.sh

echo "Starting security updates..."

# 1. Scan for vulnerabilities
trivy image --severity HIGH,CRITICAL $(kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u)

# 2. Update base images
docker images --format "table {{.Repository}}:{{.Tag}}" | grep -v REPOSITORY | while read repo tag; do
    echo "Scanning $repo:$tag"
    trivy image --exit-code 1 --severity HIGH,CRITICAL "$repo:$tag" || echo "Vulnerabilities found in $repo:$tag"
done

# 3. Rotate secrets
kubectl create secret generic new-secret --from-literal=key=value -n tractus-x
kubectl patch deployment edc-control-plane -n tractus-x -p='{"spec":{"template":{"spec":{"containers":[{"name":"edc-control-plane","env":[{"name":"SECRET_KEY","valueFrom":{"secretKeyRef":{"name":"new-secret","key":"key"}}}]}]}}}}'

# 4. Update security policies
kubectl apply -f configs/security/updated-network-policies.yaml

# 5. Certificate renewal check
cert-manager renew --all

echo "Security updates complete"
```

## Compliance and Auditing

### Audit Requirements

#### 1. Access Logging

```yaml
# Kubernetes audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log all requests at the RequestResponse level
- level: RequestResponse
  namespaces: ["tractus-x", "edc-standalone"]
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: "apps"
    resources: ["deployments", "replicasets"]

# Log metadata for all other requests
- level: Metadata
  omitStages:
  - RequestReceived
```

#### 2. Change Tracking

```bash
#!/bin/bash
# scripts/audit-changes.sh

echo "=== Change Audit Report - $(date) ==="

# Track configuration changes via GitOps
echo "Recent commits to configuration repository:"
git log --oneline --since="1 month ago" | head -20

# Track Kubernetes resource changes
echo "Recent resource modifications:"
kubectl get events -A --sort-by='.lastTimestamp' | grep -E "(Created|Updated|Deleted)" | tail -50

# Track ArgoCD deployments
echo "Recent ArgoCD sync operations:"
kubectl logs -n argocd deployment/argocd-application-controller --since=168h | grep -E "(sync|deploy)" | tail -20

# Track certificate changes
echo "Recent certificate operations:"
kubectl get events -A --field-selector=involvedObject.kind=Certificate --sort-by='.lastTimestamp' | tail -10
```

#### 3. Data Access Logging

```yaml
# EDC audit configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: edc-audit-config
  namespace: tractus-x
data:
  audit.properties: |
    # Enable audit logging
    edc.audit.enabled=true
    edc.audit.level=INFO
    
    # Log data access events
    edc.audit.data.access=true
    edc.audit.contract.negotiation=true
    edc.audit.policy.evaluation=true
    
    # Audit log format
    edc.audit.format=json
    edc.audit.destination=file
    edc.audit.file.path=/var/log/edc/audit.log
```

### Compliance Reporting

#### 1. Security Posture Assessment

```bash
#!/bin/bash
# scripts/security-posture-report.sh

echo "=== Security Posture Report - $(date) ==="

# RBAC Analysis
echo "1. RBAC Configuration:"
kubectl get clusterroles | wc -l
kubectl get roles -A | wc -l
kubectl get clusterrolebindings | wc -l
kubectl get rolebindings -A | wc -l

# Network Policy Analysis
echo "2. Network Policies:"
kubectl get networkpolicies -A | wc -l
kubectl get networkpolicies -A -o json | jq '.items | map(select(.spec.policyTypes[] == "Ingress")) | length'
kubectl get networkpolicies -A -o json | jq '.items | map(select(.spec.policyTypes[] == "Egress")) | length'

# Pod Security Standards
echo "3. Pod Security:"
kubectl get pods -A -o json | jq '.items | map(select(.spec.securityContext.runAsNonRoot == true)) | length'
kubectl get pods -A -o json | jq '.items | map(select(.spec.containers[].securityContext.readOnlyRootFilesystem == true)) | length'

# Secret Management
echo "4. Secret Management:"
kubectl get secrets -A | wc -l
kubectl get secrets -A -l type=kubernetes.io/tls | wc -l

# Image Security
echo "5. Image Security:"
kubectl get pods -A -o json | jq -r '.items[].spec.containers[].image' | grep -c ":latest" || echo "0"
```

#### 2. Data Protection Compliance

```bash
#!/bin/bash
# scripts/data-protection-report.sh

echo "=== Data Protection Compliance Report - $(date) ==="

# Encryption at rest
echo "1. Encryption at Rest:"
kubectl get secrets -A -o json | jq '.items | map(select(.type == "Opaque")) | length'
kubectl get persistentvolumes -o json | jq '.items | map(select(.spec.csi.volumeAttributes.encrypted == "true")) | length'

# Data retention policies
echo "2. Data Retention:"
kubectl get configmaps -A -o json | jq -r '.items[] | select(.metadata.name | contains("retention")) | "\(.metadata.namespace)/\(.metadata.name)"'

# Personal data handling
echo "3. Personal Data Processing:"
# Check for GDPR compliance markers
kubectl get configmaps -A -o json | jq -r '.items[] | select(.data | has("gdpr.enabled")) | "\(.metadata.namespace)/\(.metadata.name): \(.data."gdpr.enabled")"'

# Data export capabilities
echo "4. Data Portability:"
kubectl get cronjobs -A | grep -c export || echo "0"
```

#### 3. Availability and Performance Metrics

```bash
#!/bin/bash
# scripts/sla-report.sh

echo "=== SLA Compliance Report - $(date) ==="

# Calculate uptime for last 30 days
echo "1. Service Availability (last 30 days):"
kubectl exec -n monitoring deployment/prometheus -- promtool query instant \
    'avg_over_time(up{job="tractus-x-portal"}[30d])' | tail -1

kubectl exec -n monitoring deployment/prometheus -- promtool query instant \
    'avg_over_time(up{job="tractus-x-edc"}[30d])' | tail -1

# Response time SLA compliance
echo "2. Response Time SLA (95th percentile < 2s):"
kubectl exec -n monitoring deployment/prometheus -- promtool query instant \
    'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[30d]))' | tail -1

# Error rate SLA compliance
echo "3. Error Rate SLA (< 1%):"
kubectl exec -n monitoring deployment/prometheus -- promtool query instant \
    'rate(http_requests_total{status=~"5.."}[30d]) / rate(http_requests_total[30d])' | tail -1
```

## Contact Information

### Escalation Matrix

| Level | Role | Contact | Response Time | Availability |
|-------|------|---------|---------------|--------------|
| L1 | Platform Engineer | platform-l1@tractus-x.org | 15 minutes | 24/7 |
| L2 | Senior Platform Engineer | platform-l2@tractus-x.org | 30 minutes | Business hours |
| L3 | Platform Team Lead | platform-lead@tractus-x.org | 1 hour | Business hours |
| L4 | Engineering Manager | eng-manager@tractus-x.org | 2 hours | Business hours |

### Emergency Procedures

#### Critical System Outage

1. **Immediate Response (0-15 minutes)**
   - Page on-call engineer via PagerDuty
   - Create incident in incident management system
   - Start war room bridge: [Bridge Number]
   - Post initial status update in #incident-response Slack channel

2. **Assessment Phase (15-30 minutes)**
   - Assess scope and impact of outage
   - Determine if this is a P0 (complete outage) or P1 (partial outage)
   - Notify stakeholders according to communication plan
   - Begin troubleshooting following runbooks

3. **Resolution Phase (ongoing)**
   - Execute recovery procedures
   - Provide regular status updates every 30 minutes
   - Escalate to next level if no progress after 1 hour
   - Document all actions taken

4. **Post-Incident (within 24 hours)**
   - Conduct post-incident review
   - Create detailed incident report
   - Identify and implement preventive measures
   - Update runbooks and procedures

#### Communication Templates

**Initial Incident Notification:**
```
INCIDENT ALERT - P0/P1
Service: Tractus-X Platform
Impact: [Description of impact]
Start Time: [UTC timestamp]
Current Status: Investigating
ETA for Next Update: [timestamp]
Incident Commander: [name]
Bridge: [conference bridge info]
```

**Status Update:**
```
INCIDENT UPDATE - [timestamp]
Service: Tractus-X Platform
Status: [Investigating/Identified/Monitoring/Resolved]
Progress: [What has been done]
Next Steps: [What will be done next]
ETA for Next Update: [timestamp]
```

**Resolution Notification:**
```
INCIDENT RESOLVED - [timestamp]
Service: Tractus-X Platform
Resolution: [Brief description of fix]
Root Cause: [If known]
Duration: [Total outage time]
Post-Incident Review: [When it will be conducted]
```

### On-Call Procedures

#### On-Call Responsibilities

1. **Primary On-Call**
   - Respond to all P0/P1 alerts within 15 minutes
   - Own incident resolution or escalation
   - Maintain incident communication
   - Update monitoring and alerting based on incidents

2. **Secondary On-Call**
   - Backup for primary on-call
   - Respond if primary doesn't respond within 30 minutes
   - Assist with complex incidents requiring multiple people

#### Handoff Procedures

```bash
# On-call handoff checklist
echo "=== On-Call Handoff - $(date) ==="

# 1. Review current alerts
kubectl exec -n monitoring deployment/prometheus -- promtool query instant 'ALERTS{alertstate="firing"}'

# 2. Review recent incidents
# Check incident management system for open tickets

# 3. Review ongoing maintenance
# Check scheduled maintenance calendar

# 4. Review system health
./scripts/system-health-check.sh

# 5. Brief incoming on-call engineer
# Schedule handoff call

echo "Handoff complete"
```

### Service Level Agreements (SLAs)

#### Availability Targets

| Service | Availability Target | Monthly Downtime Budget |
|---------|-------------------|------------------------|
| Tractus-X Portal | 99.9% | 43.8 minutes |
| EDC Connectors | 99.95% | 21.9 minutes |
| ArgoCD | 99.5% | 3.6 hours |
| Monitoring Stack | 99.5% | 3.6 hours |

#### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| API Response Time | 95th percentile < 2s | 30-day rolling average |
| Data Transfer Rate | > 100 MB/s | Per transfer |
| Contract Negotiation | < 30 seconds | End-to-end |
| Dashboard Load Time | < 3 seconds | Initial page load |

---

This playbook should be reviewed and updated quarterly to ensure it remains current with the deployed infrastructure and operational procedures. All team members should be familiar with the procedures outlined in this document.