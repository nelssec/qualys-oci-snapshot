# Integration Tests

These tests require a deployed OCI environment. Set the following environment variables:

- `SCANNING_COMPARTMENT_ID` - Compartment OCID for scanning tenancy
- `TARGET_TENANCY_ID` - Target tenancy OCID
- `TARGET_COMPARTMENT_ID` - Target compartment OCID
- `OCI_REGION` - OCI region (default: us-ashburn-1)
- `API_GATEWAY_ENDPOINT` - API Gateway base URL
- `API_KEY` - API key for authentication

Run with:
  npm run test:integration
