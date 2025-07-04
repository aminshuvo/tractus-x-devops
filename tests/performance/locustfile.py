"""
Locust performance test file for web-based load testing
Usage: locust -f locustfile.py --host=http://minikube-ip:port
"""

from locust import HttpUser, task, between
import json

class EDCUser(HttpUser):
    """Locust user for EDC performance testing"""
    
    wait_time = between(1, 3)  # Wait 1-3 seconds between requests
    
    def on_start(self):
        """Called when a user starts"""
        # Test connectivity
        self.client.get("/api/check/health")
    
    @task(3)
    def health_check(self):
        """Health check endpoint - most frequent"""
        self.client.get("/api/check/health")
    
    @task(2)
    def readiness_check(self):
        """Readiness check endpoint"""
        self.client.get("/api/check/readiness")
    
    @task(1)
    def list_assets(self):
        """List assets - less frequent"""
        self.client.get("/api/management/v2/assets")
    
    @task(1)
    def list_policies(self):
        """List policies - less frequent"""
        self.client.get("/api/management/v2/policydefinitions")


class TractusXUser(HttpUser):
    """Locust user for general Tractus-X services"""
    
    wait_time = between(2, 5)
    
    @task
    def health_checks(self):
        """Perform various health checks"""
        endpoints = [
            "/api/check/health",
            "/api/check/readiness"
        ]
        
        for endpoint in endpoints:
            self.client.get(endpoint)