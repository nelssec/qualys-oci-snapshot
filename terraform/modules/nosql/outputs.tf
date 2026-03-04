output "resource_inventory_table_id" {
  description = "OCID of the resource inventory table"
  value       = oci_nosql_table.resource_inventory.id
}

output "resource_inventory_table_name" {
  description = "Name of the resource inventory table"
  value       = oci_nosql_table.resource_inventory.name
}

output "scan_status_table_id" {
  description = "OCID of the scan status table"
  value       = oci_nosql_table.scan_status.id
}

output "scan_status_table_name" {
  description = "Name of the scan status table"
  value       = oci_nosql_table.scan_status.name
}

output "event_logs_table_id" {
  description = "OCID of the event logs table"
  value       = oci_nosql_table.event_logs.id
}

output "event_logs_table_name" {
  description = "Name of the event logs table"
  value       = oci_nosql_table.event_logs.name
}

output "discovery_task_table_id" {
  description = "OCID of the discovery task table"
  value       = oci_nosql_table.discovery_task.id
}

output "discovery_task_table_name" {
  description = "Name of the discovery task table"
  value       = oci_nosql_table.discovery_task.name
}

output "app_config_table_id" {
  description = "OCID of the app config table"
  value       = oci_nosql_table.app_config.id
}

output "app_config_table_name" {
  description = "Name of the app config table"
  value       = oci_nosql_table.app_config.name
}

output "all_table_ids" {
  description = "List of all NoSQL table OCIDs"
  value = [
    oci_nosql_table.resource_inventory.id,
    oci_nosql_table.scan_status.id,
    oci_nosql_table.event_logs.id,
    oci_nosql_table.discovery_task.id,
    oci_nosql_table.app_config.id,
  ]
}
