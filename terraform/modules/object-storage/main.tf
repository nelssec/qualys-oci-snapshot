# Object Storage Module - Buckets for scan results and artifacts

resource "oci_objectstorage_bucket" "scan_data" {
  compartment_id = var.compartment_id
  namespace      = var.object_storage_namespace
  name           = "snapshot-scan-data-${var.region}"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"

  auto_tiering = "InfrequentAccess"

  freeform_tags = var.common_tags
}

resource "oci_objectstorage_bucket" "artifacts" {
  compartment_id = var.compartment_id
  namespace      = var.object_storage_namespace
  name           = "snapshot-artifacts"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"

  freeform_tags = var.common_tags
}

# Lifecycle rule to clean up old scan results
resource "oci_objectstorage_object_lifecycle_policy" "scan_data_lifecycle" {
  namespace = var.object_storage_namespace
  bucket    = oci_objectstorage_bucket.scan_data.name

  rules {
    name        = "delete-old-scan-results"
    action      = "DELETE"
    time_amount = var.scan_data_retention_days
    time_unit   = "DAYS"
    is_enabled  = true
    target      = "objects"

    object_name_filter {
      inclusion_prefixes = ["scan-results/"]
    }
  }
}
