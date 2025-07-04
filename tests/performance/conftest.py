"""
Pytest configuration for performance tests
"""

import pytest

def pytest_configure(config):
    """Configure pytest for performance tests"""
    config.addinivalue_line(
        "markers", "stress: marks tests as stress tests (deselect with '-m \"not stress\"')"
    )

@pytest.fixture(scope="session")
def service_endpoints():
    """Get service endpoints for performance testing"""
    # This would typically be implemented to discover service endpoints
    # For now, return empty dict - the actual implementation would query k8s
    return {}