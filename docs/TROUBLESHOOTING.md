# Troubleshooting Guide

This guide provides solutions to common issues encountered when deploying and operating the Tractus-X system.

## Quick Diagnostic Commands

### System Health Check

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes
kubectl get pods -A | grep -v Running

# Check ArgoCD applications
kubectl get applications -n argocd

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

### Service Status

```bash
# Check service endpoints
minikube service list

# Test service connectivity
kubectl exec -it <pod-name> -n <namespace> -- curl <service-url>

# Check ingress
kubectl get ingress -A
```

### Resource Monitoring

```bash
# Check pod resource usage
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Check node resource usage
kubectl describe nodes

# Check persistent volumes
kubectl get pv,pvc -A
```

## Common Issues and Solutions

### 1. Minikube Issues

#### Issue: Minikube won't start

**Symptoms:**
- `minikube start` fails
- Error messages about VirtualBox/Docker driver
- Insufficient resources error

**Diagnostic Commands:**
```bash
# Check Docker daemon status
docker version
docker info

# Check available system resources
free -h
df -h

# Check virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo
```

**Solutions:**

```bash
# Solution 1: Reset Minikube
minikube delete
minikube start --memory=8192 --cpus=4 --disk-size=20GB

# Solution 2: Check Docker is running
sudo systemctl status docker  # Linux
brew services list | grep docker  # macOS

# Solution 3: Increase resources if needed
minikube config set memory 12288
minikube config set cpus 6
minikube delete && minikube start

# Solution 4: Change driver if issues persist
minikube start --driver=virtualbox
minikube start --driver=hyperkit  # macOS
```

#### Issue: Minikube addons not working

**Symptoms:**
- Ingress not accessible
- Metrics server not working
- Dashboard unavailable

**Diagnostic Commands:**
```bash
# Check addon status
minikube addons list

# Check addon pods
kubectl get pods -n ingress-nginx
kubectl get pods -n kube-system | grep metrics-server
```

**Solutions:**

```bash
# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable storage-provisioner

# Restart addons if needed
minikube addons disable ingress
minikube addons enable ingress

# Check addon logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

#### Issue: Minikube IP not accessible

**Symptoms:**
- Cannot access services via minikube IP
- Network connectivity issues
- DNS resolution problems

**Diagnostic Commands:**
```bash
# Check minikube IP
minikube ip

# Test connectivity
ping $(minikube ip)

# Check port forwarding
netstat -tuln | grep <port>
```

**Solutions:**

```bash
# Update /etc/hosts
echo "$(minikube ip) tractus-x.minikube.local argocd.minikube.local grafana.minikube.local" | sudo tee -a /etc/hosts

# Use port forwarding instead of ingress
kubectl port-forward -n argocd svc/argocd-server 8080:443
kubectl port-forward -n monitoring svc/grafana 3000:80

# Restart minikube tunnel (if using LoadBalancer services)
minikube tunnel
```

### 2. Kubernetes Issues

#### Issue: Pods stuck in Pending state

**Symptoms:**
- Pods show "Pending" status
- `kubectl describe pod` shows scheduling issues

**Diagnostic Commands:**
```bash
# Check pod details
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl describe nodes
kubectl top nodes

# Check pod resource requests
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 resources
```

**Solutions:**

```bash
# Solution 1: Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Solution 2: Increase cluster resources
minikube stop
minikube start --memory=12288 --cpus=6

# Solution 3: Check for taints and tolerations
kubectl describe node minikube | grep Taints

# Solution 4: Check storage class
kubectl get storageclass
kubectl get pvc -A | grep Pending

# Solution 5: Remove resource requests temporarily
kubectl patch deployment <deployment-name> -n <namespace> -p='{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{}}]}}}}'
```

#### Issue: Pods in CrashLoopBackOff

**Symptoms:**
- Pods continuously restarting
- High restart count in `kubectl get pods`

**Diagnostic Commands:**
```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check resource limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 resources
```

**Solutions:**

```bash
# Solution 1: Check application logs
kubectl logs -f <pod-name> -n <namespace>

# Solution 2: Check configuration
kubectl get configmap -n <namespace>
kubectl describe configmap <configmap-name> -n <namespace>

# Solution 3: Increase resource limits
kubectl patch deployment <deployment-name> -n <namespace> -p='{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'

# Solution 4: Check environment variables
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep -A 20 env

# Solution 5: Check liveness/readiness probes
kubectl patch deployment <deployment-name> -n <namespace> -p='{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","livenessProbe":null,"readinessProbe":null}]}}}}'
```

#### Issue: ImagePullBackOff errors

**Symptoms:**
- Pods can't pull container images
- Error messages about image not found

**Diagnostic Commands:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check image name and tag
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep image
```

**Solutions:**

```bash
# Solution 1: For Minikube, ensure using Docker daemon
eval $(minikube docker-env)

# Solution 2: Check if image exists
docker images | grep <image-name>

# Solution 3: Pull image manually
docker pull <image-name>:<tag>

# Solution 4: Fix image name/tag
kubectl patch deployment <deployment-name> -n <namespace> -p='{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","image":"<correct-image-name>:<tag>"}]}}}}'

# Solution 5: Add image pull secrets (if needed)
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>
```

### 3. ArgoCD Issues

#### Issue: Applications not syncing

**Symptoms:**
- ArgoCD shows "OutOfSync" status
- Applications not deploying changes
- Sync operation fails

**Diagnostic Commands:**
```bash
# Check ArgoCD application status
kubectl get applications -n argocd
argocd app list

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Check repository connectivity
kubectl logs -n argocd deployment/argocd-repo-server
```

**Solutions:**

```bash
# Solution 1: Manual sync
kubectl patch application -n argocd <app-name> --type json \
  -p='[{"op": "replace", "path": "/operation", "value": null}]'

# Solution 2: Force refresh
argocd app sync <app-name> --force

# Solution 3: Check repository credentials
kubectl get secret -n argocd argocd-repo-<repo-name> -o yaml

# Solution 4: Update repository URL
argocd repo add <new-repo-url> --type git

# Solution 5: Reset application
argocd app delete <app-name>
kubectl apply -f kubernetes/argocd/applications/<app-name>.yaml
```

#### Issue: ArgoCD UI not accessible

**Symptoms:**
- Cannot access ArgoCD web interface
- Connection timeout or refused

**Diagnostic Commands:**
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD service
kubectl get svc -n argocd
```

**Solutions:**

```bash
# Solution 1: Port forward to ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Solution 2: Check ingress configuration
kubectl get ingress -n argocd
kubectl describe ingress -n argocd argocd-server

# Solution 3: Reset admin password
kubectl delete secret -n argocd argocd-initial-admin-secret
kubectl rollout restart -n argocd deployment/argocd-server

# Solution 4: Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server | grep -i error
```

#### Issue: ArgoCD sync hooks failing

**Symptoms:**
- Pre/post sync hooks fail
- Applications stuck in sync state

**Diagnostic Commands:**
```bash
# Check hook job status
kubectl get jobs -n <namespace>

# Check hook job logs
kubectl logs job/<job-name> -n <namespace>
```

**Solutions:**

```bash
# Solution 1: Delete failed hook jobs
kubectl delete job <job-name> -n <namespace>

# Solution 2: Skip hooks during sync
argocd app sync <app-name> --strategy=apply

# Solution 3: Check hook resource requirements
kubectl describe job <job-name> -n <namespace>
```

### 4. EDC Connector Issues

#### Issue: EDC health check failing

**Symptoms:**
- `/api/check/health` returns 500 error
- EDC pods restarting frequently
- Connection refused errors

**Diagnostic Commands:**
```bash
# Check EDC pod logs
kubectl logs -n tractus-x deployment/edc-control-plane
kubectl logs -n edc-standalone deployment/edc-control-plane

# Check EDC pod status
kubectl describe pod -n tractus-x -l app.kubernetes.io/name=edc

# Test EDC health endpoint
curl $(minikube service -n tractus-x edc-control-plane --url)/api/check/health
```

**Solutions:**

```bash
# Solution 1: Check configuration
kubectl get configmap -n tractus-x edc-config -o yaml

# Solution 2: Verify database connectivity
kubectl exec -it <edc-pod> -n tractus-x -- nc -zv postgres-service 5432

# Solution 3: Check resource usage
kubectl top pod -n tractus-x | grep edc

# Solution 4: Restart EDC deployment
kubectl rollout restart -n tractus-x deployment/edc-control-plane

# Solution 5: Check environment variables
kubectl get deployment -n tractus-x edc-control-plane -o yaml | grep -A 20 env
```

#### Issue: EDC connectors can't communicate

**Symptoms:**
- Catalog requests fail
- Contract negotiation errors
- Network timeout between connectors

**Diagnostic Commands:**
```bash
# Check service endpoints
kubectl get svc -A | grep edc

# Test connectivity between connectors
kubectl exec -it <consumer-pod> -n tractus-x -- \
  curl <provider-url>/api/check/health

# Check network policies
kubectl get networkpolicies -A
```

**Solutions:**

```bash
# Solution 1: Check service endpoints
kubectl get endpoints -A | grep edc

# Solution 2: Verify DSP endpoints
kubectl logs -n tractus-x deployment/edc-control-plane | grep DSP

# Solution 3: Test network connectivity
kubectl exec -it <pod> -n tractus-x -- nslookup edc-control-plane.edc-standalone.svc.cluster.local

# Solution 4: Check firewall rules
kubectl describe networkpolicy -A

# Solution 5: Port forward for testing
kubectl port-forward -n edc-standalone svc/edc-control-plane 8080:8080
```

#### Issue: EDC contract negotiation failing

**Symptoms:**
- Contract negotiations timeout
- Policy evaluation errors
- Authorization failures

**Diagnostic Commands:**
```bash
# Check EDC management API logs
kubectl logs -n tractus-x deployment/edc-control-plane | grep -i contract

# Check policy configuration
kubectl get configmap -n tractus-x edc-policies -o yaml
```

**Solutions:**

```bash
# Solution 1: Verify asset configuration
curl -X GET "$(minikube service -n tractus-x edc-control-plane --url)/api/management/v2/assets"

# Solution 2: Check policy definitions
curl -X GET "$(minikube service -n tractus-x edc-control-plane --url)/api/management/v2/policydefinitions"

# Solution 3: Verify contract definitions
curl -X GET "$(minikube service -n tractus-x edc-control-plane --url)/api/management/v2/contractdefinitions"

# Solution 4: Check participant ID configuration
kubectl get configmap -n tractus-x edc-config -o yaml | grep participant
```

### 5. Monitoring Issues

#### Issue: Prometheus targets down

**Symptoms:**
- Prometheus UI shows targets as "DOWN"
- Missing metrics in Grafana
- Scrape errors in Prometheus logs

**Diagnostic Commands:**
```bash
# Check Prometheus targets
curl "$(minikube service -n monitoring prometheus-server --url)/api/v1/targets"

# Check Prometheus configuration
kubectl get configmap -n monitoring prometheus-config -o yaml

# Check service discovery
kubectl logs -n monitoring deployment/prometheus-server
```

**Solutions:**

```bash
# Solution 1: Verify service annotations
kubectl get svc -A -o yaml | grep prometheus.io

# Solution 2: Test target endpoints manually
kubectl exec -it <prometheus-pod> -n monitoring -- \
  wget -qO- http://<target-service>:<port>/metrics

# Solution 3: Check network policies
kubectl get networkpolicies -n monitoring

# Solution 4: Restart Prometheus
kubectl rollout restart -n monitoring deployment/prometheus-server

# Solution 5: Verify service discovery configuration
kubectl describe configmap -n monitoring prometheus-config
```

#### Issue: Grafana dashboards not loading

**Symptoms:**
- Grafana shows "No data" message
- Dashboard errors or timeouts
- Data source connection issues

**Diagnostic Commands:**
```bash
# Check Grafana logs
kubectl logs -n monitoring deployment/grafana

# Test Prometheus data source
kubectl exec -it <grafana-pod> -n monitoring -- \
  curl http://prometheus-server:80/api/v1/query?query=up
```

**Solutions:**

```bash
# Solution 1: Check data source configuration
kubectl get configmap -n monitoring grafana-datasources -o yaml

# Solution 2: Test data source connectivity
curl "$(minikube service -n monitoring grafana --url)/api/datasources/proxy/1/api/v1/query?query=up"

# Solution 3: Reset Grafana configuration
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

# Solution 4: Check dashboard configuration
kubectl get configmap -n monitoring grafana-dashboards -o yaml

# Solution 5: Import dashboard manually
curl -X POST -H "Content-Type: application/json" \
  -d @configs/grafana/dashboards/tractus-x-overview.json \
  "$(minikube service -n monitoring grafana --url)/api/dashboards/db"
```

#### Issue: Logs not appearing in Loki

**Symptoms:**
- Loki shows no logs
- Promtail not scraping logs
- Log queries return empty results

**Diagnostic Commands:**
```bash
# Check Promtail logs
kubectl logs -n monitoring daemonset/promtail

# Check Loki logs
kubectl logs -n monitoring deployment/loki

# Test log query
curl "$(minikube service -n monitoring loki --url)/loki/api/v1/query?query={namespace=\"tractus-x\"}"
```

**Solutions:**

```bash
# Solution 1: Verify log file paths
kubectl exec -it <promtail-pod> -n monitoring -- ls -la /var/log/pods

# Solution 2: Check Promtail configuration
kubectl get configmap -n monitoring promtail-config -o yaml

# Solution 3: Test Loki ingestion
kubectl exec -it <loki-pod> -n monitoring -- \
  wget -qO- 'http://localhost:3100/loki/api/v1/query?query={namespace="tractus-x"}'

# Solution 4: Restart log collection
kubectl rollout restart -n monitoring daemonset/promtail
kubectl rollout restart -n monitoring deployment/loki

# Solution 5: Check log labels
kubectl logs -n monitoring daemonset/promtail | grep -i label
```

### 6. Networking Issues

#### Issue: Services not accessible via Ingress

**Symptoms:**
- 404 errors when accessing services
- Ingress controller errors
- DNS resolution issues

**Diagnostic Commands:**
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify ingress configuration
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>
```

**Solutions:**

```bash
# Solution 1: Check service backend
kubectl get endpoints <service-name> -n <namespace>

# Solution 2: Test internal connectivity
kubectl exec -it <test-pod> -- curl http://<service-name>.<namespace>:80

# Solution 3: Update /etc/hosts for local access
echo "$(minikube ip) tractus-x.minikube.local argocd.minikube.local" | sudo tee -a /etc/hosts

# Solution 4: Check ingress class
kubectl get ingressclass

# Solution 5: Recreate ingress
kubectl delete ingress <ingress-name> -n <namespace>
kubectl apply -f <ingress-manifest>
```

#### Issue: DNS resolution problems

**Symptoms:**
- Services can't resolve other services
- nslookup failures inside pods
- Connection timeouts

**Diagnostic Commands:**
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system deployment/coredns

# Test DNS resolution
kubectl exec -it <pod-name> -n <namespace> -- nslookup kubernetes.default
```

**Solutions:**

```bash
# Solution 1: Check DNS configuration
kubectl get configmap -n kube-system coredns -o yaml

# Solution 2: Restart CoreDNS
kubectl rollout restart -n kube-system deployment/coredns

# Solution 3: Test specific service resolution
kubectl exec -it <pod> -- nslookup <service-name>.<namespace>.svc.cluster.local

# Solution 4: Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Solution 5: Verify network policies
kubectl get networkpolicies -A
```

#### Issue: Inter-pod communication blocked

**Symptoms:**
- Pods cannot communicate with each other
- Network policies blocking traffic
- Connection refused errors

**Diagnostic Commands:**
```bash
# Check network policies
kubectl get networkpolicies -A
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test pod-to-pod connectivity
kubectl exec -it <pod-a> -n <namespace-a> -- curl <pod-b-ip>
```

**Solutions:**

```bash
# Solution 1: Create allow-all network policy temporarily
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
EOF

# Solution 2: Check specific network policy rules
kubectl get networkpolicy <policy-name> -n <namespace> -o yaml

# Solution 3: Test without network policies
kubectl delete networkpolicy --all -n <namespace>

# Solution 4: Debug with netshoot
kubectl run netshoot --rm -i --tty --image nicolaka/netshoot -- /bin/bash
```

### 7. Storage Issues

#### Issue: Persistent Volume claims pending

**Symptoms:**
- PVCs stuck in "Pending" state
- Storage class not found errors
- Volume mount failures

**Diagnostic Commands:**
```bash
# Check storage classes
kubectl get storageclass

# Check persistent volumes
kubectl get pv
kubectl describe pv <pv-name>

# Check PVC status
kubectl describe pvc <pvc-name> -n <namespace>
```

**Solutions:**

```bash
# Solution 1: For Minikube, ensure storage provisioner
minikube addons enable storage-provisioner

# Solution 2: Create manual PV if needed
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /tmp/manual-pv
EOF

# Solution 3: Check dynamic provisioning
kubectl get pods -n kube-system | grep storage-provisioner

# Solution 4: Fix storage class
kubectl patch storageclass <storage-class> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

#### Issue: Database connectivity problems

**Symptoms:**
- Applications can't connect to database
- Database authentication failures
- Connection pool exhaustion

**Diagnostic Commands:**
```bash
# Check database pod status
kubectl get pods -n <namespace> | grep postgres

# Check database logs
kubectl logs -n <namespace> deployment/postgresql

# Test database connectivity
kubectl exec -it <app-pod> -n <namespace> -- nc -zv <db-service> 5432
```

**Solutions:**

```bash
# Solution 1: Check database credentials
kubectl get secret -n <namespace> postgres-secret -o yaml

# Solution 2: Test database connection
kubectl exec -it <postgres-pod> -n <namespace> -- psql -U postgres -c "\l"

# Solution 3: Check database service
kubectl get svc -n <namespace> | grep postgres
kubectl describe svc postgres -n <namespace>

# Solution 4: Restart database
kubectl rollout restart -n <namespace> deployment/postgresql
```

### 8. Performance Issues

#### Issue: High resource usage

**Symptoms:**
- Pods using excessive CPU/memory
- Cluster becomes unresponsive
- Out of memory errors

**Diagnostic Commands:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Limits
```

**Solutions:**

```bash
# Solution 1: Increase cluster resources
minikube stop
minikube start --memory=16384 --cpus=8

# Solution 2: Adjust pod resource limits
kubectl patch deployment <deployment-name> -n <namespace> --patch='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "resources": {
            "limits": {
              "memory": "2Gi",
              "cpu": "1000m"
            },
            "requests": {
              "memory": "1Gi",
              "cpu": "500m"
            }
          }
        }]
      }
    }
  }
}'

# Solution 3: Enable horizontal pod autoscaling
kubectl autoscale deployment <deployment-name> --cpu-percent=50 --min=1 --max=10

# Solution 4: Check for memory leaks
kubectl exec -it <pod-name> -n <namespace> -- top
```

#### Issue: Slow application response times

**Symptoms:**
- High API response times
- Database query slowness
- Dashboard loading issues

**Diagnostic Commands:**
```bash
# Check application metrics
curl "$(minikube service -n monitoring prometheus-server --url)/api/v1/query?query=http_request_duration_seconds"

# Check database performance
kubectl exec -it <postgres-pod> -n <namespace> -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

**Solutions:**

```bash
# Solution 1: Scale up application
kubectl scale deployment <deployment-name> -n <namespace> --replicas=3

# Solution 2: Add database indexes
kubectl exec -it <postgres-pod> -n <namespace> -- psql -U postgres -d <database> -c "CREATE INDEX ON <table> (<column>);"

# Solution 3: Tune JVM settings (for Java apps)
kubectl patch deployment <deployment-name> -n <namespace> -p='{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","env":[{"name":"JAVA_OPTS","value":"-Xms1g -Xmx2g"}]}]}}}}'

# Solution 4: Enable caching
kubectl patch deployment <deployment-name> -n <namespace> -p='{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","env":[{"name":"ENABLE_CACHE","value":"true"}]}]}}}}'
```

## Recovery Procedures

### Complete System Recovery

If the entire system needs to be rebuilt:

```bash
# 1. Backup current state
kubectl get all -A > system-backup.yaml
kubectl get configmaps -A > configmaps-backup.yaml
kubectl get secrets -A > secrets-backup.yaml

# 2. Reset Minikube
minikube delete
minikube start --memory=12288 --cpus=6

# 3. Redeploy infrastructure
cd terraform
terraform destroy -auto-approve
terraform apply -auto-approve

# 4. Redeploy applications
./scripts/deploy-all.sh

# 5. Verify system
kubectl get pods -A
pytest tests/integration/ -v
```

### Partial Service Recovery

For individual service issues:

```bash
# Restart deployment
kubectl rollout restart deployment <deployment-name> -n <namespace>

# Scale down and up
kubectl scale deployment <deployment-name> -n <namespace> --replicas=0
sleep 30
kubectl scale deployment <deployment-name> -n <namespace> --replicas=1

# Delete and recreate pod
kubectl delete pod <pod-name> -n <namespace>

# Sync ArgoCD application
argocd app sync <app-name>
```

### Database Recovery

For database-related issues:

```bash
# 1. Backup database
kubectl exec -n <namespace> deployment/postgresql -- pg_dumpall -U postgres > backup.sql

# 2. Restart database
kubectl rollout restart -n <namespace> deployment/postgresql

# 3. Restore from backup if needed
kubectl exec -i -n <namespace> deployment/postgresql -- psql -U postgres < backup.sql

# 4. Verify database integrity
kubectl exec -n <namespace> deployment/postgresql -- pg_dump -U postgres -d <database> --schema-only
```

## Debugging Tools and Techniques

### Essential Debugging Tools

```bash
# Install useful debugging tools in a pod
kubectl run debug-pod --rm -i --tty --image=nicolaka/netshoot -- /bin/bash

# Available tools in netshoot:
# - curl, wget (HTTP testing)
# - ping, traceroute (network connectivity)
# - nslookup, dig (DNS testing)
# - netstat, ss (network statistics)
# - tcpdump (packet capture)
# - iperf3 (network performance)
```

### Log Analysis

```bash
# Stream logs from multiple pods
kubectl logs -f -l app=<app-name> -n <namespace>

# Search logs for errors
kubectl logs -n <namespace> <pod-name> | grep -i error

# Export logs for analysis
kubectl logs --since=1h -n <namespace> <pod-name> > debug.log

# Use stern for advanced log tailing
stern -n <namespace> <pod-prefix>
```

### Performance Profiling

```bash
# CPU profiling
kubectl exec -it <pod-name> -n <namespace> -- top

# Memory analysis
kubectl exec -it <pod-name> -n <namespace> -- cat /proc/meminfo

# Disk usage
kubectl exec -it <pod-name> -n <namespace> -- df -h

# Network statistics
kubectl exec -it <pod-name> -n <namespace> -- netstat -i
```

### Advanced Debugging

```bash
# Debug container networking
kubectl exec -it <pod-name> -n <namespace> -- ip route show
kubectl exec -it <pod-name> -n <namespace> -- iptables -L

# Check container processes
kubectl exec -it <pod-name> -n <namespace> -- ps aux

# File system debugging
kubectl exec -it <pod-name> -n <namespace> -- ls -la /
kubectl exec -it <pod-name> -n <namespace> -- mount | grep /var
```

## Getting Additional Help

### Log Collection

When reporting issues, collect these logs:

```bash
# System information
kubectl version
minikube version
docker version

# Cluster state
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by='.lastTimestamp'

# Service logs
kubectl logs -n <namespace> deployment/<deployment-name> --tail=100

# Resource usage
kubectl top nodes
kubectl top pods -A

# Configuration dumps
kubectl get configmaps -A -o yaml > configmaps.yaml
kubectl get secrets -A -o yaml > secrets.yaml
```

### Diagnostic Script

Create a comprehensive diagnostic script:

```bash
#!/bin/bash
# scripts/collect-diagnostics.sh

echo "=== Tractus-X Diagnostic Information ==="
echo "Timestamp: $(date)"
echo "========================================"

echo "## System Information"
kubectl version
minikube version
docker version

echo "## Cluster Status"
kubectl cluster-info
kubectl get nodes -o wide
kubectl get componentstatuses

echo "## Pod Status"
kubectl get pods -A -o wide

echo "## Service Status"
kubectl get svc -A

echo "## Ingress Status"
kubectl get ingress -A

echo "## Storage Status"
kubectl get pv,pvc -A

echo "## Recent Events"
kubectl get events -A --sort-by='.lastTimestamp' | tail -50

echo "## Resource Usage"
kubectl top nodes
kubectl top pods -A

echo "## ArgoCD Applications"
kubectl get applications -n argocd

echo "## Log Samples"
for ns in tractus-x edc-standalone monitoring argocd; do
    echo "=== Logs from namespace: $ns ==="
    kubectl logs --tail=20 -n $ns -l app.kubernetes.io/name=$(kubectl get pods -n $ns -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/name}' 2>/dev/null) 2>/dev/null || echo "No logs available"
done
```

### Contact Information

When you need additional support:

1. **GitHub Issues**: Create an issue with diagnostic information
2. **Documentation**: Check other documentation files in the `docs/` directory
3. **Community Support**: Refer to Tractus-X and EDC community channels

### Useful Resources

- [Kubernetes Troubleshooting Guide](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [ArgoCD Troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)
- [Eclipse Dataspace Components Documentation](https://eclipse-edc.github.io/docs/)
- [Minikube Troubleshooting](https://minikube.sigs.k8s.io/docs/handbook/troubleshooting/)
- [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)
- [Grafana Troubleshooting](https://grafana.com/docs/grafana/latest/troubleshooting/)

## Preventive Measures

### Regular Health Checks

```bash
# Daily health check script
#!/bin/bash
# scripts/daily-health-check.sh

echo "=== Daily Health Check - $(date) ==="

# Check cluster health
kubectl get nodes | grep -v Ready && echo "Node issues detected"

# Check critical pods
kubectl get pods -A | grep -E "(CrashLoopBackOff|Error|Pending)" && echo "Pod issues detected"

# Check disk space
kubectl exec -n monitoring deployment/prometheus-server -- df -h | grep -E "([89][0-9]%|100%)" && echo "Disk space issues detected"

# Check certificate expiration
./scripts/monitor-certificates.sh

# Generate summary report
echo "Health check completed at $(date)"
```

### Monitoring Setup

```bash
# Set up monitoring alerts for common issues
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: troubleshooting-alerts
  namespace: monitoring
spec:
  groups:
  - name: troubleshooting
    rules:
    - alert: PodRestartingFrequently
      expr: rate(kube_pod_container_status_restarts_total[1h]) > 0.1
      for: 5m
      annotations:
        summary: "Pod {{ \$labels.pod }} is restarting frequently"
    
    - alert: NodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      annotations:
        summary: "Node {{ \$labels.node }} is not ready"
EOF
```

---

