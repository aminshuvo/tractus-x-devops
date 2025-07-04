"""
Pytest configuration for integration tests
"""

import pytest
import subprocess
import time

def pytest_configure(config):
    """Configure pytest"""
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )

@pytest.fixture(scope="session", autouse=True)
def setup_test_environment():
    """Setup test environment"""
    # Wait for services to be ready
    print("Waiting for services to be ready...")
    time.sleep(30)
    
    # Verify minikube is running
    try:
        subprocess.run(['minikube', 'status'], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        pytest.exit("Minikube is not running. Please start minikube first.")
    
    yield
    
    # Cleanup after tests
    print("Integration tests completed")