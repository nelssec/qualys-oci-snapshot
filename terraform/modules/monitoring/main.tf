# Monitoring Module - Logging, Monitoring, Alarms

# Log Group for all scanner components
resource "oci_logging_log_group" "scanner_log_group" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-logs"
  description    = "Log group for snapshot scanner components"

  freeform_tags = var.common_tags
}

# Function invocation logs
resource "oci_logging_log" "function_invoke_log" {
  display_name = "snapshot-scanner-function-invoke"
  log_group_id = oci_logging_log_group.scanner_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "invoke"
      resource    = var.function_application_id
      service     = "functions"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = var.common_tags
}

# API Gateway access logs
resource "oci_logging_log" "apigw_access_log" {
  display_name = "snapshot-scanner-apigw-access"
  log_group_id = oci_logging_log_group.scanner_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "access"
      resource    = var.api_gateway_id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = var.common_tags
}

# API Gateway execution logs
resource "oci_logging_log" "apigw_execution_log" {
  display_name = "snapshot-scanner-apigw-execution"
  log_group_id = oci_logging_log_group.scanner_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "execution"
      resource    = var.api_gateway_id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = var.common_tags
}

# Alarm: Function errors
resource "oci_monitoring_alarm" "function_errors" {
  compartment_id        = var.compartment_id
  display_name          = "snapshot-scanner-function-errors"
  is_enabled            = true
  metric_compartment_id = var.compartment_id
  namespace             = "oci_faas"
  query                 = "FunctionInvocationCount[5m]{functionName =~ \"snapshot-.*\", response_status = \"error\"}.sum() > ${var.function_error_threshold}"
  severity              = "CRITICAL"
  body                  = "Snapshot scanner function invocation errors exceeded threshold"

  destinations = var.alarm_notification_topic_ids

  freeform_tags = var.common_tags
}

# Alarm: Queue depth (backup requests backing up)
resource "oci_monitoring_alarm" "queue_depth" {
  compartment_id        = var.compartment_id
  display_name          = "snapshot-scanner-queue-depth"
  is_enabled            = true
  metric_compartment_id = var.compartment_id
  namespace             = "oci_queue"
  query                 = "MessagesInQueue[5m]{queueName = \"snapshot-backup-requests\"}.max() > ${var.queue_depth_threshold}"
  severity              = "WARNING"
  body                  = "Snapshot scanner backup request queue depth exceeded threshold"

  destinations = var.alarm_notification_topic_ids

  freeform_tags = var.common_tags
}

# Alarm: DLQ messages (failures)
resource "oci_monitoring_alarm" "dlq_messages" {
  compartment_id        = var.compartment_id
  display_name          = "snapshot-scanner-dlq-messages"
  is_enabled            = true
  metric_compartment_id = var.compartment_id
  namespace             = "oci_queue"
  query                 = "MessagesInQueue[5m]{queueName =~ \"snapshot-.*-dlq\"}.sum() > 0"
  severity              = "CRITICAL"
  body                  = "Messages detected in snapshot scanner dead letter queue(s)"

  destinations = var.alarm_notification_topic_ids

  freeform_tags = var.common_tags
}

# Notification topic for alarms
resource "oci_ons_notification_topic" "scanner_alarms" {
  compartment_id = var.compartment_id
  name           = "snapshot-scanner-alarms"
  description    = "Notification topic for snapshot scanner alarms"

  freeform_tags = var.common_tags
}

# Email subscription (optional)
resource "oci_ons_subscription" "email_subscription" {
  count = var.alarm_email != "" ? 1 : 0

  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.scanner_alarms.id
  endpoint       = var.alarm_email
  protocol       = "EMAIL"
}
