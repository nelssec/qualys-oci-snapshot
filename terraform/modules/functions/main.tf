# Functions Module - OCI Functions Application + 23 Function definitions

resource "oci_functions_application" "scanner_app" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-app"
  subnet_ids     = var.subnet_ids

  config = {
    COMPARTMENT_ID       = var.compartment_id
    SCANNING_TENANCY_ID  = var.tenancy_id
    QFLOW_ENDPOINT       = var.qflow_endpoint
    VAULT_ID             = var.vault_id
    MASTER_KEY_ID        = var.master_key_id
    SCANNER_SUBNET_ID    = var.scanner_subnet_id
    SCANNER_NSG_ID       = var.scanner_nsg_id
    SCANNER_IMAGE_ID     = var.scanner_image_id
    LOG_LEVEL            = var.log_level
  }

  freeform_tags = var.common_tags
}

# Scanning tenancy functions (22)
resource "oci_functions_function" "oci_sdk_wrapper" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "oci-sdk-wrapper"
  image          = "${var.ocir_registry}/snapshot-scanner/oci-sdk-wrapper:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "data_formatter" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "data-formatter"
  image          = "${var.ocir_registry}/snapshot-scanner/data-formatter:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "nosql_wrapper" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "nosql-wrapper"
  image          = "${var.ocir_registry}/snapshot-scanner/nosql-wrapper:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "create_scan_status" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "create-scan-status"
  image          = "${var.ocir_registry}/snapshot-scanner/create-scan-status:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "generate_scan_chunks" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "generate-scan-chunks"
  image          = "${var.ocir_registry}/snapshot-scanner/generate-scan-chunks:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "fetch_inventory_chunks" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "fetch-inventory-chunks"
  image          = "${var.ocir_registry}/snapshot-scanner/fetch-inventory-chunks:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "generate_scan_params" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "generate-scan-params"
  image          = "${var.ocir_registry}/snapshot-scanner/generate-scan-params:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "app_config_store" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "app-config-store"
  image          = "${var.ocir_registry}/snapshot-scanner/app-config-store:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "stack_cleanup" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "stack-cleanup"
  image          = "${var.ocir_registry}/snapshot-scanner/stack-cleanup:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "image_cleanup" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "image-cleanup"
  image          = "${var.ocir_registry}/snapshot-scanner/image-cleanup:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "discovery_worker" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "discovery-worker"
  image          = "${var.ocir_registry}/snapshot-scanner/discovery-worker:${var.image_tag}"
  memory_in_mbs  = 512
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "discovery_scheduler" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "discovery-scheduler"
  image          = "${var.ocir_registry}/snapshot-scanner/discovery-scheduler:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "image_discovery_scheduler" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "image-discovery-scheduler"
  image          = "${var.ocir_registry}/snapshot-scanner/image-discovery-scheduler:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "event_task_scheduler" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "event-task-scheduler"
  image          = "${var.ocir_registry}/snapshot-scanner/event-task-scheduler:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "scheduled_fn_check" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "scheduled-fn-check"
  image          = "${var.ocir_registry}/snapshot-scanner/scheduled-fn-check:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "post_process_scan" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "post-process-scan"
  image          = "${var.ocir_registry}/snapshot-scanner/post-process-scan:${var.image_tag}"
  memory_in_mbs  = 512
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "process_scan_files" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "process-scan-files"
  image          = "${var.ocir_registry}/snapshot-scanner/process-scan-files:${var.image_tag}"
  memory_in_mbs  = 512
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "on_demand_scan" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "on-demand-scan"
  image          = "${var.ocir_registry}/snapshot-scanner/on-demand-scan:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "download_to_storage" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "download-to-storage"
  image          = "${var.ocir_registry}/snapshot-scanner/download-to-storage:${var.image_tag}"
  memory_in_mbs  = 512
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "update_function_code" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "update-function-code"
  image          = "${var.ocir_registry}/snapshot-scanner/update-function-code:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 300
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "create_bucket" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "create-bucket"
  image          = "${var.ocir_registry}/snapshot-scanner/create-bucket:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "qflow_api" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "qflow-api"
  image          = "${var.ocir_registry}/snapshot-scanner/qflow-api:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}

resource "oci_functions_function" "proxy_instance" {
  application_id = oci_functions_application.scanner_app.id
  display_name   = "proxy-instance"
  image          = "${var.ocir_registry}/snapshot-scanner/proxy-instance:${var.image_tag}"
  memory_in_mbs  = 256
  timeout_in_seconds = 120
  freeform_tags  = var.common_tags
}
