# Events Module - OCI Events Rules + Connector Hub

# Connector Hub: NoSQL resource_inventory table -> qflow (via qflow-api Function)
resource "oci_sch_service_connector" "inventory_to_qflow" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-inventory-to-qflow"

  source {
    kind = "streaming"
    cursor {
      kind = "LATEST"
    }
    stream_id = var.resource_inventory_stream_id
  }

  target {
    kind        = "functions"
    function_id = var.qflow_api_function_id
  }

  freeform_tags = var.common_tags
}

# Connector Hub: NoSQL scan_status table -> qflow
resource "oci_sch_service_connector" "scan_status_to_qflow" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-scan-status-to-qflow"

  source {
    kind = "streaming"
    cursor {
      kind = "LATEST"
    }
    stream_id = var.scan_status_stream_id
  }

  target {
    kind        = "functions"
    function_id = var.qflow_api_function_id
  }

  freeform_tags = var.common_tags
}

# Connector Hub: NoSQL event_logs table -> qflow
resource "oci_sch_service_connector" "event_logs_to_qflow" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-event-logs-to-qflow"

  source {
    kind = "streaming"
    cursor {
      kind = "LATEST"
    }
    stream_id = var.event_logs_stream_id
  }

  target {
    kind        = "functions"
    function_id = var.qflow_api_function_id
  }

  freeform_tags = var.common_tags
}

# Connector Hub: NoSQL discovery_task table -> qflow
resource "oci_sch_service_connector" "discovery_task_to_qflow" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-discovery-task-to-qflow"

  source {
    kind = "streaming"
    cursor {
      kind = "LATEST"
    }
    stream_id = var.discovery_task_stream_id
  }

  target {
    kind        = "functions"
    function_id = var.qflow_api_function_id
  }

  freeform_tags = var.common_tags
}

# Connector Hub: NoSQL app_config table -> qflow
resource "oci_sch_service_connector" "app_config_to_qflow" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-app-config-to-qflow"

  source {
    kind = "streaming"
    cursor {
      kind = "LATEST"
    }
    stream_id = var.app_config_stream_id
  }

  target {
    kind        = "functions"
    function_id = var.qflow_api_function_id
  }

  freeform_tags = var.common_tags
}
