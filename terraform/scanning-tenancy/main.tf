# Scanning Tenancy Root Module
# Composes all modules into the complete scanning infrastructure

# --- IAM ---
module "iam" {
  source = "../modules/iam"

  tenancy_id         = var.tenancy_id
  compartment_id     = var.compartment_id
  target_tenancy_ids = var.target_tenancy_ids
  common_tags        = var.common_tags
}

# --- Vault ---
module "vault" {
  source = "../modules/vault"

  compartment_id      = var.compartment_id
  qflow_token         = var.qflow_token
  scanner_platforms   = ["LINUX", "WINDOWS"]
  scan_interval_hours = var.scan_interval_hours
  common_tags         = var.common_tags
}

# --- Networking ---
module "vcn" {
  source = "../modules/vcn"

  compartment_id       = var.compartment_id
  vcn_cidr             = var.vcn_cidr
  subnet_cidr          = var.subnet_cidr
  create_public_subnet = true
  common_tags          = var.common_tags
}

# --- NoSQL Tables ---
module "nosql" {
  source = "../modules/nosql"

  compartment_id = var.compartment_id
  common_tags    = var.common_tags
}

# --- Queues ---
module "queues" {
  source = "../modules/queues"

  compartment_id            = var.compartment_id
  max_concurrent_backups    = 10
  single_region_concurrency = var.single_region_concurrency
  common_tags               = var.common_tags
}

# --- Object Storage ---
module "object_storage" {
  source = "../modules/object-storage"

  compartment_id           = var.compartment_id
  object_storage_namespace = var.object_storage_namespace
  region                   = var.region
  common_tags              = var.common_tags
}

# --- Functions ---
module "functions" {
  source = "../modules/functions"

  compartment_id    = var.compartment_id
  tenancy_id        = var.tenancy_id
  subnet_ids        = [module.vcn.private_subnet_id]
  scanner_subnet_id = module.vcn.private_subnet_id
  scanner_nsg_id    = module.vcn.scanner_nsg_id
  scanner_image_id  = var.scanner_image_id
  qflow_endpoint    = var.qflow_endpoint
  vault_id          = module.vault.vault_id
  master_key_id     = module.vault.master_key_id
  ocir_registry     = var.ocir_registry
  image_tag         = var.image_tag
  log_level         = var.log_level
  common_tags       = var.common_tags

  depends_on = [module.iam]
}

# --- API Gateway ---
module "api_gateway" {
  source = "../modules/api-gateway"

  compartment_id                   = var.compartment_id
  subnet_id                        = module.vcn.public_subnet_id
  event_task_scheduler_function_id = module.functions.function_ids["event_task_scheduler"]
  oci_sdk_wrapper_function_id      = module.functions.function_ids["oci_sdk_wrapper"]
  auth_function_id                 = module.functions.function_ids["qflow_api"]
  common_tags                      = var.common_tags
}

# --- Events / Connector Hub ---
module "events" {
  source = "../modules/events"

  compartment_id      = var.compartment_id
  qflow_api_function_id = module.functions.function_ids["qflow_api"]
  common_tags         = var.common_tags

  # Stream IDs will be configured post-deployment when NoSQL table streams are enabled
  resource_inventory_stream_id = ""
  scan_status_stream_id        = ""
  event_logs_stream_id         = ""
  discovery_task_stream_id     = ""
  app_config_stream_id         = ""
}

# --- Monitoring ---
module "monitoring" {
  source = "../modules/monitoring"

  compartment_id          = var.compartment_id
  function_application_id = module.functions.application_id
  api_gateway_id          = module.api_gateway.gateway_id
  alarm_email             = var.alarm_email
  alarm_notification_topic_ids = []
  common_tags             = var.common_tags
}
