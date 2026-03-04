output "connector_ids" {
  description = "Map of connector hub names to OCIDs"
  value = {
    inventory_to_qflow      = oci_sch_service_connector.inventory_to_qflow.id
    scan_status_to_qflow    = oci_sch_service_connector.scan_status_to_qflow.id
    event_logs_to_qflow     = oci_sch_service_connector.event_logs_to_qflow.id
    discovery_task_to_qflow = oci_sch_service_connector.discovery_task_to_qflow.id
    app_config_to_qflow     = oci_sch_service_connector.app_config_to_qflow.id
  }
}
