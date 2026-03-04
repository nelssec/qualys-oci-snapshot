# Target Tenancy Root Module
# Cross-tenancy admit policies + event forwarding infrastructure

# --- Cross-tenancy Admit Policies ---
# These policies allow the scanning tenancy's dynamic group to operate here

resource "oci_identity_policy" "cross_tenancy_admit" {
  compartment_id = var.tenancy_id  # Must be at root compartment
  name           = "snapshot-scanner-cross-tenancy-admit"
  description    = "Allow scanning tenancy to perform snapshot scanning operations"

  statements = [
    "define tenancy ScanningTenancy as ${var.scanning_tenancy_id}",
    "define dynamic-group SnapshotScannerFunctions as ${var.scanning_dynamic_group_id}",
    "admit dynamic-group SnapshotScannerFunctions of tenancy ScanningTenancy to manage volume-backups in tenancy",
    "admit dynamic-group SnapshotScannerFunctions of tenancy ScanningTenancy to manage boot-volume-backups in tenancy",
    "admit dynamic-group SnapshotScannerFunctions of tenancy ScanningTenancy to inspect instances in tenancy",
    "admit dynamic-group SnapshotScannerFunctions of tenancy ScanningTenancy to inspect volumes in tenancy",
    "admit dynamic-group SnapshotScannerFunctions of tenancy ScanningTenancy to read boot-volume-attachments in tenancy",
    "admit dynamic-group SnapshotScannerFunctions of tenancy ScanningTenancy to read volume-attachments in tenancy",
    "admit dynamic-group SnapshotScannerFunctions of tenancy ScanningTenancy to use keys in tenancy",
  ]

  freeform_tags = var.common_tags
}

# --- Event Forwarding (optional, for event-based scanning) ---

# Function Application for event-forwarder
resource "oci_functions_application" "event_forwarder_app" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-event-forwarder"
  subnet_ids     = [oci_core_subnet.event_forwarder_subnet[0].id]

  config = {
    SCANNING_API_ENDPOINT = var.scanning_api_gateway_endpoint
    API_KEY               = var.qflow_token
  }

  freeform_tags = var.common_tags
}

# Event-forwarder Function
resource "oci_functions_function" "event_forwarder" {
  count = var.event_based_scan ? 1 : 0

  application_id     = oci_functions_application.event_forwarder_app[0].id
  display_name       = "event-forwarder"
  image              = var.event_forwarder_ocir_image
  memory_in_mbs      = 256
  timeout_in_seconds = 30

  freeform_tags = var.common_tags
}

# Dynamic group for event-forwarder function
resource "oci_identity_dynamic_group" "event_forwarder" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.tenancy_id
  name           = "snapshot-scanner-event-forwarder"
  description    = "Dynamic group for event forwarder function"
  matching_rule  = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_id}'}"

  freeform_tags = var.common_tags
}

# Policy for event-forwarder to be invoked by Events service
resource "oci_identity_policy" "event_forwarder_policy" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.tenancy_id
  name           = "snapshot-scanner-event-forwarder-policy"
  description    = "Allow Events service to invoke event-forwarder function"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.event_forwarder[0].name} to use functions-family in compartment id ${var.compartment_id}",
    "Allow service cloudevents to use functions-family in compartment id ${var.compartment_id}",
  ]

  freeform_tags = var.common_tags
}

# OCI Events Rule - Instance launch/running events
resource "oci_events_rule" "instance_launch" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-instance-events"
  description    = "Forward instance launch events to scanning tenancy"
  is_enabled     = true

  condition = jsonencode({
    eventType = [
      "com.oraclecloud.computeapi.launchinstance.end"
    ]
  })

  actions {
    actions {
      action_type = "FAAS"
      is_enabled  = true
      function_id = oci_functions_function.event_forwarder[0].id
      description = "Forward to event-forwarder function"
    }
  }

  freeform_tags = var.common_tags
}

# OCI Events Rule - Custom image available events
resource "oci_events_rule" "image_available" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-image-events"
  description    = "Forward custom image events to scanning tenancy"
  is_enabled     = true

  condition = jsonencode({
    eventType = [
      "com.oraclecloud.computeapi.createimage.end"
    ]
  })

  actions {
    actions {
      action_type = "FAAS"
      is_enabled  = true
      function_id = oci_functions_function.event_forwarder[0].id
      description = "Forward to event-forwarder function"
    }
  }

  freeform_tags = var.common_tags
}

# Minimal VCN for event-forwarder function
resource "oci_core_vcn" "event_forwarder_vcn" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-event-fwd-vcn"
  cidr_blocks    = ["10.20.0.0/28"]
  dns_label      = "snapevtfwd"

  freeform_tags = var.common_tags
}

resource "oci_core_subnet" "event_forwarder_subnet" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.event_forwarder_vcn[0].id
  display_name   = "snapshot-scanner-event-fwd-subnet"
  cidr_block     = "10.20.0.0/28"
  dns_label      = "evtfwd"

  route_table_id = oci_core_route_table.event_forwarder_rt[0].id

  freeform_tags = var.common_tags
}

resource "oci_core_nat_gateway" "event_forwarder_nat" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.event_forwarder_vcn[0].id
  display_name   = "snapshot-scanner-event-fwd-nat"

  freeform_tags = var.common_tags
}

resource "oci_core_route_table" "event_forwarder_rt" {
  count = var.event_based_scan ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.event_forwarder_vcn[0].id
  display_name   = "snapshot-scanner-event-fwd-rt"

  route_rules {
    network_entity_id = oci_core_nat_gateway.event_forwarder_nat[0].id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }

  freeform_tags = var.common_tags
}
