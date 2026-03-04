output "scanner_functions_dynamic_group_id" {
  description = "OCID of the scanner functions dynamic group"
  value       = oci_identity_dynamic_group.scanner_functions.id
}

output "scanner_functions_dynamic_group_name" {
  description = "Name of the scanner functions dynamic group"
  value       = oci_identity_dynamic_group.scanner_functions.name
}

output "scanner_instances_dynamic_group_id" {
  description = "OCID of the scanner instances dynamic group"
  value       = oci_identity_dynamic_group.scanner_instances.id
}

output "scanner_instances_dynamic_group_name" {
  description = "Name of the scanner instances dynamic group"
  value       = oci_identity_dynamic_group.scanner_instances.name
}

output "api_gateway_dynamic_group_id" {
  description = "OCID of the API Gateway dynamic group"
  value       = oci_identity_dynamic_group.api_gateway.id
}

output "functions_policy_id" {
  description = "OCID of the functions policy"
  value       = oci_identity_policy.scanner_functions_policy.id
}

output "instances_policy_id" {
  description = "OCID of the instances policy"
  value       = oci_identity_policy.scanner_instances_policy.id
}
