# --- Core Infrastructure ---

output "compartment_id" {
  description = "Compartment OCID used for all resources"
  value       = var.compartment_id
}

# --- Networking ---

output "vcn_id" {
  description = "VCN OCID"
  value       = module.vcn.vcn_id
}

output "private_subnet_id" {
  description = "Private subnet OCID for scanner instances"
  value       = module.vcn.private_subnet_id
}

output "scanner_nsg_id" {
  description = "NSG OCID for scanner instances"
  value       = module.vcn.scanner_nsg_id
}

# --- Functions ---

output "function_application_id" {
  description = "Function Application OCID"
  value       = module.functions.application_id
}

output "function_ids" {
  description = "Map of function names to OCIDs"
  value       = module.functions.function_ids
}

# --- API Gateway ---

output "api_gateway_hostname" {
  description = "API Gateway hostname for event forwarding"
  value       = module.api_gateway.gateway_hostname
}

output "events_endpoint" {
  description = "Full URL for the /events endpoint"
  value       = module.api_gateway.events_endpoint
}

# --- Vault ---

output "vault_id" {
  description = "Vault OCID"
  value       = module.vault.vault_id
}

output "master_key_id" {
  description = "Master encryption key OCID"
  value       = module.vault.master_key_id
}

# --- NoSQL ---

output "nosql_table_ids" {
  description = "List of all NoSQL table OCIDs"
  value       = module.nosql.all_table_ids
}

# --- Queues ---

output "queue_ids" {
  description = "Map of queue names to OCIDs"
  value       = module.queues.all_queue_ids
}

# --- Object Storage ---

output "scan_data_bucket" {
  description = "Scan data bucket name"
  value       = module.object_storage.scan_data_bucket_name
}

output "artifacts_bucket" {
  description = "Artifacts bucket name"
  value       = module.object_storage.artifacts_bucket_name
}

# --- Monitoring ---

output "notification_topic_id" {
  description = "Alarm notification topic OCID"
  value       = module.monitoring.notification_topic_id
}

# --- IAM ---

output "scanner_functions_dynamic_group_id" {
  description = "Dynamic group OCID for scanner functions (needed by target tenancy)"
  value       = module.iam.scanner_functions_dynamic_group_id
}

output "scanner_functions_dynamic_group_name" {
  description = "Dynamic group name for scanner functions"
  value       = module.iam.scanner_functions_dynamic_group_name
}
