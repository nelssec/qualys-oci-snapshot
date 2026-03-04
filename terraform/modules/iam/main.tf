# IAM Module - Dynamic Groups and Policies for Scanning Tenancy

# Dynamic group for all Functions in the scanner compartment
resource "oci_identity_dynamic_group" "scanner_functions" {
  compartment_id = var.tenancy_id
  name           = "snapshot-scanner-functions"
  description    = "Dynamic group for all OCI Functions in the snapshot scanner compartment"
  matching_rule  = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_id}'}"

  freeform_tags = var.common_tags
}

# Dynamic group for scanner compute instances (by freeform tag)
resource "oci_identity_dynamic_group" "scanner_instances" {
  compartment_id = var.tenancy_id
  name           = "snapshot-scanner-instances"
  description    = "Dynamic group for scanner compute instances"
  matching_rule  = "ALL {resource.type = 'instance', tag.App.value = 'snapshot-scanner'}"

  freeform_tags = var.common_tags
}

# Dynamic group for API Gateway
resource "oci_identity_dynamic_group" "api_gateway" {
  compartment_id = var.tenancy_id
  name           = "snapshot-scanner-apigw"
  description    = "Dynamic group for API Gateway in scanner compartment"
  matching_rule  = "ALL {resource.type = 'ApiGateway', resource.compartment.id = '${var.compartment_id}'}"

  freeform_tags = var.common_tags
}

# Policy: Functions can manage all required services
resource "oci_identity_policy" "scanner_functions_policy" {
  compartment_id = var.compartment_id
  name           = "snapshot-scanner-functions-policy"
  description    = "Policy for snapshot scanner functions"

  statements = [
    # NoSQL
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage nosql-family in compartment id ${var.compartment_id}",

    # Queues
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage queues in compartment id ${var.compartment_id}",

    # Object Storage
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage objects in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage buckets in compartment id ${var.compartment_id}",

    # Compute (scanner instances)
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage instances in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage instance-family in compartment id ${var.compartment_id}",

    # Block Volume
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage volumes in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage volume-attachments in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage volume-backups in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage boot-volume-backups in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage boot-volume-attachments in compartment id ${var.compartment_id}",

    # Vault / KMS
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to use keys in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to use secret-family in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to read vaults in compartment id ${var.compartment_id}",

    # Networking
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to use virtual-network-family in compartment id ${var.compartment_id}",

    # Functions (self-update)
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage functions-family in compartment id ${var.compartment_id}",

    # Logging
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to use log-content in compartment id ${var.compartment_id}",
  ]

  freeform_tags = var.common_tags
}

# Policy: Scanner instances can upload results to Object Storage
resource "oci_identity_policy" "scanner_instances_policy" {
  compartment_id = var.compartment_id
  name           = "snapshot-scanner-instances-policy"
  description    = "Policy for scanner compute instances"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_instances.name} to manage objects in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.scanner_instances.name} to read buckets in compartment id ${var.compartment_id}",
  ]

  freeform_tags = var.common_tags
}

# Policy: API Gateway can invoke functions
resource "oci_identity_policy" "apigw_policy" {
  compartment_id = var.compartment_id
  name           = "snapshot-scanner-apigw-policy"
  description    = "Policy for API Gateway to invoke functions"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.api_gateway.name} to use functions-family in compartment id ${var.compartment_id}",
  ]

  freeform_tags = var.common_tags
}

# Cross-tenancy endorse policies (scanning tenancy root compartment)
# These allow the scanner functions to operate in target tenancies
resource "oci_identity_policy" "cross_tenancy_endorse" {
  count = length(var.target_tenancy_ids) > 0 ? 1 : 0

  compartment_id = var.tenancy_id
  name           = "snapshot-scanner-cross-tenancy-endorse"
  description    = "Endorse policies for cross-tenancy snapshot scanning"

  statements = flatten([
    for target_id in var.target_tenancy_ids : [
      "define tenancy Target_${substr(target_id, 14, 8)} as ${target_id}",
      "endorse dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage volume-backups in tenancy Target_${substr(target_id, 14, 8)}",
      "endorse dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to manage boot-volume-backups in tenancy Target_${substr(target_id, 14, 8)}",
      "endorse dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to inspect instances in tenancy Target_${substr(target_id, 14, 8)}",
      "endorse dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to inspect volumes in tenancy Target_${substr(target_id, 14, 8)}",
      "endorse dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to read boot-volume-attachments in tenancy Target_${substr(target_id, 14, 8)}",
      "endorse dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to read volume-attachments in tenancy Target_${substr(target_id, 14, 8)}",
      "endorse dynamic-group ${oci_identity_dynamic_group.scanner_functions.name} to use keys in tenancy Target_${substr(target_id, 14, 8)}",
    ]
  ])

  freeform_tags = var.common_tags
}
