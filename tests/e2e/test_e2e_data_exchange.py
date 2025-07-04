#!/usr/bin/env python3
"""
End-to-end tests for Tractus-X deployment
"""

import pytest
import requests
import time
import json
import uuid
from typing import Dict, Any
import subprocess

class TestE2EDataExchange:
    """End-to-end tests for EDC data exchange workflow"""
    
    @pytest.fixture
    def connector_a_url(self, service_endpoints):
        """Get first EDC connector URL"""
        edc_services = [endpoint for name, endpoint in service_endpoints.items() 
                       if 'edc' in name.lower() and 'tractus-x' in name]
        if not edc_services:
            pytest.skip("No Tractus-X EDC connector found")
        return edc_services[0]
    
    @pytest.fixture
    def connector_b_url(self, service_endpoints):
        """Get standalone EDC connector URL"""
        edc_services = [endpoint for name, endpoint in service_endpoints.items() 
                       if 'edc' in name.lower() and 'standalone' in name]
        if not edc_services:
            pytest.skip("No standalone EDC connector found")
        return edc_services[0]
    
    @pytest.fixture
    def test_asset_id(self):
        """Generate unique test asset ID"""
        return f"test-asset-{uuid.uuid4()}"
    
    @pytest.fixture
    def test_policy_id(self):
        """Generate unique test policy ID"""
        return f"test-policy-{uuid.uuid4()}"
    
    @pytest.fixture
    def test_contract_definition_id(self):
        """Generate unique test contract definition ID"""
        return f"test-contract-def-{uuid.uuid4()}"
    
    def create_asset(self, connector_url: str, asset_id: str) -> Dict[str, Any]:
        """Create a test asset"""
        asset_payload = {
            "@context": {
                "edc": "https://w3id.org/edc/v0.0.1/ns/"
            },
            "@id": asset_id,
            "properties": {
                "name": "Test Asset",
                "description": "Test asset for E2E testing",
                "contenttype": "application/json"
            },
            "dataAddress": {
                "type": "HttpData",
                "baseUrl": "http://httpbin.org/json"
            }
        }
        
        response = requests.post(
            f"{connector_url}/api/management/v2/assets",
            json=asset_payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        assert response.status_code in [200, 201], f"Failed to create asset: {response.text}"
        return response.json()
    
    def create_policy(self, connector_url: str, policy_id: str) -> Dict[str, Any]:
        """Create a test policy"""
        policy_payload = {
            "@context": {
                "edc": "https://w3id.org/edc/v0.0.1/ns/",
                "odrl": "http://www.w3.org/ns/odrl/2/"
            },
            "@id": policy_id,
            "policy": {
                "@type": "Policy",
                "odrl:permission": [{
                    "odrl:action": "USE",
                    "odrl:constraint": {
                        "odrl:leftOperand": "BusinessPartnerNumber",
                        "odrl:operator": "EQ",
                        "odrl:rightOperand": "BPNL000000000000"
                    }
                }]
            }
        }
        
        response = requests.post(
            f"{connector_url}/api/management/v2/policydefinitions",
            json=policy_payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        assert response.status_code in [200, 201], f"Failed to create policy: {response.text}"
        return response.json()
    
    def create_contract_definition(self, connector_url: str, contract_def_id: str, 
                                 asset_id: str, policy_id: str) -> Dict[str, Any]:
        """Create a test contract definition"""
        contract_payload = {
            "@context": {
                "edc": "https://w3id.org/edc/v0.0.1/ns/"
            },
            "@id": contract_def_id,
            "accessPolicyId": policy_id,
            "contractPolicyId": policy_id,
            "assetsSelector": [{
                "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
                "operator": "=",
                "operandRight": asset_id
            }]
        }
        
        response = requests.post(
            f"{connector_url}/api/management/v2/contractdefinitions",
            json=contract_payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        assert response.status_code in [200, 201], f"Failed to create contract definition: {response.text}"
        return response.json()
    
    def request_catalog(self, consumer_url: str, provider_url: str) -> Dict[str, Any]:
        """Request catalog from provider"""
        catalog_payload = {
            "@context": {
                "edc": "https://w3id.org/edc/v0.0.1/ns/"
            },
            "counterPartyAddress": f"{provider_url}/api/v1/dsp",
            "protocol": "dataspace-protocol-http"
        }
        
        response = requests.post(
            f"{consumer_url}/api/management/v2/catalog/request",
            json=catalog_payload,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        assert response.status_code == 200, f"Failed to request catalog: {response.text}"
        return response.json()
    
    @pytest.mark.slow
    def test_complete_data_exchange_flow(self, connector_a_url, connector_b_url,
                                       test_asset_id, test_policy_id, 
                                       test_contract_definition_id):
        """Test complete data exchange flow between two EDC connectors"""
        
        # Step 1: Setup provider (connector A) with asset, policy, and contract definition
        print(f"Creating asset {test_asset_id} on provider")
        self.create_asset(connector_a_url, test_asset_id)
        
        print(f"Creating policy {test_policy_id} on provider")
        self.create_policy(connector_a_url, test_policy_id)
        
        print(f"Creating contract definition {test_contract_definition_id} on provider")
        self.create_contract_definition(connector_a_url, test_contract_definition_id,
                                      test_asset_id, test_policy_id)
        
        # Wait for setup to propagate
        time.sleep(5)
        
        # Step 2: Consumer (connector B) requests catalog from provider
        print("Requesting catalog from provider")
        catalog = self.request_catalog(connector_b_url, connector_a_url)
        
        # Find our test asset in the catalog
        test_offer = None
        for offer in catalog.get("dcat:dataset", []):
            if offer.get("@id") == test_asset_id:
                test_offer = offer
                break
        
        assert test_offer is not None, f"Test asset {test_asset_id} not found in catalog"
        print("E2E data exchange test completed successfully!")
    
    def test_catalog_visibility(self, connector_a_url, connector_b_url, 
                              test_asset_id, test_policy_id, test_contract_definition_id):
        """Test that assets are visible in catalog between connectors"""
        
        # Create test asset on provider
        self.create_asset(connector_a_url, test_asset_id)
        self.create_policy(connector_a_url, test_policy_id)
        self.create_contract_definition(connector_a_url, test_contract_definition_id,
                                      test_asset_id, test_policy_id)
        
        # Wait for propagation
        time.sleep(5)
        
        # Request catalog
        catalog = self.request_catalog(connector_b_url, connector_a_url)
        
        # Verify asset is in catalog
        asset_found = False
        for dataset in catalog.get("dcat:dataset", []):
            if dataset.get("@id") == test_asset_id:
                asset_found = True
                break
        
        assert asset_found, f"Asset {test_asset_id} not found in catalog"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-m", "not slow"])