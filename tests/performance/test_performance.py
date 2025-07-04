#!/usr/bin/env python3
"""
Performance tests for Tractus-X deployment
"""

import pytest
import requests
import time
import concurrent.futures
import statistics
from typing import List, Dict, Any
import subprocess
import json

class TestPerformance:
    """Performance tests for Tractus-X services"""
    
    @pytest.fixture
    def performance_config(self):
        """Performance test configuration"""
        return {
            'concurrent_users': 10,
            'test_duration': 60,  # seconds
            'timeout': 30,
            'acceptable_response_time': 2.0,  # seconds
            'acceptable_error_rate': 0.05  # 5%
        }
    
    def load_test_endpoint(self, url: str, duration: int, concurrent_users: int, 
                          timeout: int) -> Dict[str, Any]:
        """Perform load test on an endpoint"""
        
        def make_request():
            """Make a single request and measure response time"""
            start_time = time.time()
            try:
                response = requests.get(url, timeout=timeout)
                response_time = time.time() - start_time
                return {
                    'success': response.status_code == 200,
                    'response_time': response_time,
                    'status_code': response.status_code
                }
            except Exception as e:
                response_time = time.time() - start_time
                return {
                    'success': False,
                    'response_time': response_time,
                    'error': str(e)
                }
        
        results = []
        start_time = time.time()
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_users) as executor:
            while time.time() - start_time < duration:
                # Submit batch of requests
                futures = [executor.submit(make_request) for _ in range(concurrent_users)]
                
                # Collect results
                for future in concurrent.futures.as_completed(futures):
                    try:
                        result = future.result()
                        results.append(result)
                    except Exception as e:
                        results.append({
                            'success': False,
                            'response_time': timeout,
                            'error': str(e)
                        })
                
                # Brief pause between batches
                time.sleep(0.1)
        
        return self.analyze_results(results)
    
    def analyze_results(self, results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze load test results"""
        total_requests = len(results)
        successful_requests = len([r for r in results if r['success']])
        failed_requests = total_requests - successful_requests
        
        response_times = [r['response_time'] for r in results if r['success']]
        
        if response_times:
            avg_response_time = statistics.mean(response_times)
            min_response_time = min(response_times)
            max_response_time = max(response_times)
            p95_response_time = statistics.quantiles(response_times, n=20)[18]  # 95th percentile
            p99_response_time = statistics.quantiles(response_times, n=100)[98]  # 99th percentile
        else:
            avg_response_time = min_response_time = max_response_time = 0
            p95_response_time = p99_response_time = 0
        
        error_rate = failed_requests / total_requests if total_requests > 0 else 0
        
        return {
            'total_requests': total_requests,
            'successful_requests': successful_requests,
            'failed_requests': failed_requests,
            'error_rate': error_rate,
            'avg_response_time': avg_response_time,
            'min_response_time': min_response_time,
            'max_response_time': max_response_time,
            'p95_response_time': p95_response_time,
            'p99_response_time': p99_response_time
        }
    
    @pytest.mark.slow
    def test_edc_health_endpoint_performance(self, service_endpoints, performance_config):
        """Test EDC health endpoint performance under load"""
        
        edc_services = [endpoint for name, endpoint in service_endpoints.items() 
                       if 'edc' in name.lower()]
        
        if not edc_services:
            pytest.skip("No EDC services found")
        
        for edc_url in edc_services:
            health_url = f"{edc_url}/api/check/health"
            
            print(f"Load testing EDC health endpoint: {health_url}")
            results = self.load_test_endpoint(
                health_url,
                performance_config['test_duration'],
                performance_config['concurrent_users'],
                performance_config['timeout']
            )
            
            # Assertions
            assert results['error_rate'] <= performance_config['acceptable_error_rate'], \
                f"Error rate {results['error_rate']} exceeds acceptable rate"
            
            assert results['avg_response_time'] <= performance_config['acceptable_response_time'], \
                f"Average response time {results['avg_response_time']}s exceeds acceptable limit"
            
            print(f"Performance results for {health_url}:")
            print(f"  Total requests: {results['total_requests']}")
            print(f"  Error rate: {results['error_rate']:.2%}")
            print(f"  Avg response time: {results['avg_response_time']:.3f}s")
            print(f"  95th percentile: {results['p95_response_time']:.3f}s")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])