# Queues Module - OCI Queue Service with DLQs

# Resource Events Queue (receives forwarded events from target tenancies)
resource "oci_queue_queue" "resource_events" {
  compartment_id              = var.compartment_id
  display_name                = "snapshot-resource-events"
  dead_letter_queue_delivery_count = 3
  retention_in_seconds        = 345600  # 4 days
  visibility_in_seconds       = 30
  timeout_in_seconds          = 20
  channel_consumption_limit   = 10

  freeform_tags = var.common_tags
}

resource "oci_queue_queue" "resource_events_dlq" {
  compartment_id         = var.compartment_id
  display_name           = "snapshot-resource-events-dlq"
  retention_in_seconds   = 1209600  # 14 days
  visibility_in_seconds  = 30
  timeout_in_seconds     = 20

  freeform_tags = var.common_tags
}

# Discovery Tasks Queue
resource "oci_queue_queue" "discovery_tasks" {
  compartment_id              = var.compartment_id
  display_name                = "snapshot-discovery-tasks"
  dead_letter_queue_delivery_count = 3
  retention_in_seconds        = 345600
  visibility_in_seconds       = 300  # 5 min visibility for long-running discovery
  timeout_in_seconds          = 20
  channel_consumption_limit   = 5

  freeform_tags = var.common_tags
}

resource "oci_queue_queue" "discovery_tasks_dlq" {
  compartment_id         = var.compartment_id
  display_name           = "snapshot-discovery-tasks-dlq"
  retention_in_seconds   = 1209600
  visibility_in_seconds  = 30
  timeout_in_seconds     = 20

  freeform_tags = var.common_tags
}

# Backup Requests Queue
resource "oci_queue_queue" "backup_requests" {
  compartment_id              = var.compartment_id
  display_name                = "snapshot-backup-requests"
  dead_letter_queue_delivery_count = 3
  retention_in_seconds        = 345600
  visibility_in_seconds       = 300
  timeout_in_seconds          = 20
  channel_consumption_limit   = var.max_concurrent_backups

  freeform_tags = var.common_tags
}

resource "oci_queue_queue" "backup_requests_dlq" {
  compartment_id         = var.compartment_id
  display_name           = "snapshot-backup-requests-dlq"
  retention_in_seconds   = 1209600
  visibility_in_seconds  = 30
  timeout_in_seconds     = 20

  freeform_tags = var.common_tags
}

# Scan Requests Queue
resource "oci_queue_queue" "scan_requests" {
  compartment_id              = var.compartment_id
  display_name                = "snapshot-scan-requests"
  dead_letter_queue_delivery_count = 3
  retention_in_seconds        = 345600
  visibility_in_seconds       = 600  # 10 min for scan instance launch
  timeout_in_seconds          = 20
  channel_consumption_limit   = var.single_region_concurrency

  freeform_tags = var.common_tags
}

resource "oci_queue_queue" "scan_requests_dlq" {
  compartment_id         = var.compartment_id
  display_name           = "snapshot-scan-requests-dlq"
  retention_in_seconds   = 1209600
  visibility_in_seconds  = 30
  timeout_in_seconds     = 20

  freeform_tags = var.common_tags
}

# Post-Process Queue
resource "oci_queue_queue" "post_process" {
  compartment_id              = var.compartment_id
  display_name                = "snapshot-post-process"
  dead_letter_queue_delivery_count = 3
  retention_in_seconds        = 345600
  visibility_in_seconds       = 120
  timeout_in_seconds          = 20
  channel_consumption_limit   = 10

  freeform_tags = var.common_tags
}

resource "oci_queue_queue" "post_process_dlq" {
  compartment_id         = var.compartment_id
  display_name           = "snapshot-post-process-dlq"
  retention_in_seconds   = 1209600
  visibility_in_seconds  = 30
  timeout_in_seconds     = 20

  freeform_tags = var.common_tags
}

# Failed Errors Queue (for error tracking and analysis)
resource "oci_queue_queue" "failed_errors" {
  compartment_id         = var.compartment_id
  display_name           = "snapshot-failed-errors"
  retention_in_seconds   = 1209600  # 14 days
  visibility_in_seconds  = 30
  timeout_in_seconds     = 20

  freeform_tags = var.common_tags
}

resource "oci_queue_queue" "failed_errors_dlq" {
  compartment_id         = var.compartment_id
  display_name           = "snapshot-failed-errors-dlq"
  retention_in_seconds   = 1209600
  visibility_in_seconds  = 30
  timeout_in_seconds     = 20

  freeform_tags = var.common_tags
}
