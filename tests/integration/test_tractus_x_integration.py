#!/usr/bin/env python3
"""
Integration tests for Tractus-X deployment
"""

import pytest
import requests
import time
import json
import subprocess
from typing import Dict, List
import yaml

class TestTractusXIntegration:
    """Integration tests for Tractus-X services"""
    
    @pytest.fixture
    def kubectl_config(self):
        """Setup kubectl configuration for minikube"""
        try:
            result = subprocess.run(['kubectl', 'config', 'current-context'], 
                                  capture_output=True, text=True, check=True)
            assert 'minikube' in result.stdout
            return True
        except subprocess.CalledProcessError:
            pytest.skip("kubectl not configured for minikube")
    
    @pytest.fixture
    def service_endpoints(self, kubectl_config):
        """Get service endpoints from minikube"""
        services = {}
        try:
            # Get minikube IP
            result = subprocess.run(['minikube', 'ip'], 
                                  capture_output=True, text=True, check=True)
            minikube_ip = result.stdout.strip()
            
            # Get NodePort services
            result = subprocess.run(['kubectl', 'get', 'svc', '-A', '-o', 'json'], 
                                  capture_output=True, text=True, check=True)
            svc_data = json.loads(result.stdout)
            
            for item in svc_data['items']:
                if item['spec'].get('type') == 'NodePort':
                    name = item['metadata']['name']
                    namespace = item['metadata']['namespace']
                    for port in item['spec']['ports']:
                        node_port = port.get('nodePort')
                        if node_port:
                            services[f"{namespace}/{name}"] = f"http://{minikube_ip}:{node_port}"
            
            return services
        except Exception as e:
            pytest.skip(f"Could not get service endpoints: {e}")
    
    def test_kubernetes_cluster_ready(self, kubectl_config):
        """Test that Kubernetes cluster is ready"""
        result = subprocess.run(['kubectl', 'get', 'nodes'], 
                              capture_output=True, text=True, check=True)
        assert 'Ready' in result.stdout
    
    def test_tractus_x_namespace_exists(self, kubectl_config):
        """Test that Tractus-X namespace exists"""
        result = subprocess.run(['kubectl', 'get', 'namespace', 'tractus-x'], 
                              capture_output=True, text=True, check=True)
        assert 'tractus-x' in result.stdout
    
    def test_edc_standalone_namespace_exists(self, kubectl_config):
        """Test that EDC standalone namespace exists"""
        result = subprocess.run(['kubectl', 'get', 'namespace', 'edc-standalone'], 
                              capture_output=True, text=True, check=True)
        assert 'edc-standalone' in result.stdout
    
    def test_pods_running_in_tractus_x(self, kubectl_config):
        """Test that pods are running in Tractus-X namespace"""
        result = subprocess.run(['kubectl', 'get', 'pods', '-n', 'tractus-x'], 
                              capture_output=True, text=True, check=True)
        
        # Check that there are running pods
        lines = result.stdout.split('\n')[1:]  # Skip header
        running_pods = [line for line in lines if line and 'Running' in line]
        assert len(running_pods) > 0, "No running pods in tractus-x namespace"
    
    def test_argocd_application_sync(self, kubectl_config):
        """Test that ArgoCD applications are synced"""
        try:
            result = subprocess.run(['kubectl', 'get', 'applications', '-n', 'argocd', '-o', 'json'], 
                                  capture_output=True, text=True, check=True)
            apps_data = json.loads(result.stdout)
            
            for app in apps_data['items']:
                sync_status = app['status']['sync']['status']
                health_status = app['status']['health']['status']
                
                assert sync_status == 'Synced', f"Application {app['metadata']['name']} not synced"
                assert health_status == 'Healthy', f"Application {app['metadata']['name']} not healthy"
        except subprocess.CalledProcessError:
            pytest.skip("ArgoCD applications not found")
    
    def test_monitoring_stack_running(self, kubectl_config):
        """Test that monitoring stack is running"""
        monitoring_services = ['prometheus-server', 'grafana', 'loki']
        
        for service in monitoring_services:
            result = subprocess.run(['kubectl', 'get', 'pods', '-A', '-l', f'app.kubernetes.io/name={service}'], 
                                  capture_output=True, text=True, check=True)
            assert 'Running' in result.stdout, f"{service} not running"
    
    @pytest.mark.slow
    def test_edc_connector_health(self, service_endpoints):
        """Test EDC connector health endpoints"""
        edc_services = [endpoint for name, endpoint in service_endpoints.items() 
                       if 'edc' in name.lower()]
        
        for endpoint in edc_services:
            try:
                response = requests.get(f"{endpoint}/api/check/health", timeout=10)
                assert response.status_code == 200, f"EDC health check failed for {endpoint}"
                
                health_data = response.json()
                assert health_data.get('isSystemHealthy', False), f"EDC system not healthy: {endpoint}"
            except requests.RequestException as e:
                pytest.fail(f"Could not reach EDC endpoint {endpoint}: {e}")
    
    @pytest.mark.slow
    def test_edc_catalog_api(self, service_endpoints):
        """Test EDC catalog API"""
        edc_services = [endpoint for name, endpoint in service_endpoints.items() 
                       if 'edc' in name.lower() and 'control' in name.lower()]
        
        for endpoint in edc_services:
            try:
                # Test catalog request
                catalog_url = f"{endpoint}/api/management/v2/catalog/request"
                payload = {
                    "counterPartyAddress": "http://localhost:8080/api/v1/dsp",
                    "protocol": "dataspace-protocol-http"
                }
                
                response = requests.post(catalog_url, json=payload, timeout=10)
                # EDC might return 400 if no actual counter party, but endpoint should be reachable
                assert response.status_code in [200, 400], f"Catalog API not reachable: {endpoint}"
                
            except requests.RequestException as e:
                pytest.fail(f"Could not reach EDC catalog API {endpoint}: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])