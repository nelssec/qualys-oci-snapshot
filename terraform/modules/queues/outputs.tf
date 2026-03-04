output "resource_events_queue_id" {
  value = oci_queue_queue.resource_events.id
}

output "resource_events_dlq_id" {
  value = oci_queue_queue.resource_events_dlq.id
}

output "discovery_tasks_queue_id" {
  value = oci_queue_queue.discovery_tasks.id
}

output "discovery_tasks_dlq_id" {
  value = oci_queue_queue.discovery_tasks_dlq.id
}

output "backup_requests_queue_id" {
  value = oci_queue_queue.backup_requests.id
}

output "backup_requests_dlq_id" {
  value = oci_queue_queue.backup_requests_dlq.id
}

output "scan_requests_queue_id" {
  value = oci_queue_queue.scan_requests.id
}

output "scan_requests_dlq_id" {
  value = oci_queue_queue.scan_requests_dlq.id
}

output "post_process_queue_id" {
  value = oci_queue_queue.post_process.id
}

output "post_process_dlq_id" {
  value = oci_queue_queue.post_process_dlq.id
}

output "failed_errors_queue_id" {
  value = oci_queue_queue.failed_errors.id
}

output "failed_errors_dlq_id" {
  value = oci_queue_queue.failed_errors_dlq.id
}

output "all_queue_ids" {
  description = "Map of all queue names to IDs"
  value = {
    resource_events = oci_queue_queue.resource_events.id
    discovery_tasks = oci_queue_queue.discovery_tasks.id
    backup_requests = oci_queue_queue.backup_requests.id
    scan_requests   = oci_queue_queue.scan_requests.id
    post_process    = oci_queue_queue.post_process.id
    failed_errors   = oci_queue_queue.failed_errors.id
  }
}
