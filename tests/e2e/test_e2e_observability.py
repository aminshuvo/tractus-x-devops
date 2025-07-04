"""
End-to-end observability tests
"""

import pytest
import requests
import time
import json

class TestE2EObservability:
    """End-to-end tests for observability stack"""
    
    def test_metrics_collection_flow(self, service_endpoints):
        """Test complete metrics collection flow"""
        prometheus_url = None
        grafana_url = None
        
        for name, endpoint in service_endpoints.items():
            if 'prometheus' in name.lower():
                prometheus_url = endpoint
            elif 'grafana' in name.lower():
                grafana_url = endpoint
        
        if not prometheus_url or not grafana_url:
            pytest.skip("Prometheus or Grafana not available")
        
        # Test Prometheus is collecting metrics
        response = requests.get(f"{prometheus_url}/api/v1/query?query=up", timeout=10)
        assert response.status_code == 200
        
        metrics_data = response.json()
        assert metrics_data['status'] == 'success'
        assert len(metrics_data['data']['result']) > 0
        
        # Test Grafana can query Prometheus
        # Login to Grafana (if needed) and test data source
        health_response = requests.get(f"{grafana_url}/api/health", timeout=10)
        assert health_response.status_code == 200
    
    def test_log_aggregation_flow(self, service_endpoints):
        """Test complete log aggregation flow"""
        loki_url = None
        grafana_url = None
        
        for name, endpoint in service_endpoints.items():
            if 'loki' in name.lower():
                loki_url = endpoint
            elif 'grafana' in name.lower():
                grafana_url = endpoint
        
        if not loki_url:
            pytest.skip("Loki not available")
        
        # Test Loki is ready
        response = requests.get(f"{loki_url}/ready", timeout=10)
        assert response.status_code == 200
        
        # Test log query
        query_url = f"{loki_url}/loki/api/v1/query_range"
        params = {
            'query': '{namespace="tractus-x"}',
            'start': str(int(time.time() - 3600) * 1000000000),  # 1 hour ago in nanoseconds
            'end': str(int(time.time()) * 1000000000)  # now in nanoseconds
        }
        
        response = requests.get(query_url, params=params, timeout=10)
        # Loki might return empty results, but should be reachable
        assert response.status_code in [200, 204]
    
    def test_alerting_pipeline(self, service_endpoints):
        """Test alerting pipeline configuration"""
        prometheus_url = None
        
        for name, endpoint in service_endpoints.items():
            if 'prometheus' in name.lower():
                prometheus_url = endpoint
                break
        
        if not prometheus_url:
            pytest.skip("Prometheus not available")
        
        # Test alert rules are loaded
        response = requests.get(f"{prometheus_url}/api/v1/rules", timeout=10)
        assert response.status_code == 200
        
        rules_data = response.json()
        assert rules_data['status'] == 'success'
        
        # Check that we have some rules defined
        rule_groups = rules_data['data']['groups']
        assert len(rule_groups) > 0, "No alert rules configured"