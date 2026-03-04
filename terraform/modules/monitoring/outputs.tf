output "log_group_id" {
  description = "OCID of the log group"
  value       = oci_logging_log_group.scanner_log_group.id
}

output "notification_topic_id" {
  description = "OCID of the notification topic"
  value       = oci_ons_notification_topic.scanner_alarms.id
}

output "function_invoke_log_id" {
  value = oci_logging_log.function_invoke_log.id
}

output "apigw_access_log_id" {
  value = oci_logging_log.apigw_access_log.id
}
