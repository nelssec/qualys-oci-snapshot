# Vault Module - OCI Vault, Master Encryption Key, and Secrets

resource "oci_kms_vault" "scanner_vault" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-scanner-vault"
  vault_type     = "DEFAULT"

  freeform_tags = var.common_tags
}

resource "oci_kms_key" "master_key" {
  compartment_id = var.compartment_id
  display_name   = "snapshot-master-key"

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  management_endpoint = oci_kms_vault.scanner_vault.management_endpoint

  protection_mode = "HSM"

  freeform_tags = var.common_tags
}

# Secret for qflow subscription token
resource "oci_vault_secret" "qflow_token" {
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.scanner_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "snapshot-qflow-token"
  description    = "qflow subscription token for snapshot scanner"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.qflow_token)
  }

  freeform_tags = var.common_tags
}

# Secret for scanner image configuration
resource "oci_vault_secret" "scanner_config" {
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.scanner_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = "snapshot-scanner-config"
  description    = "Scanner instance configuration"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(jsonencode({
      scannerPlatforms = var.scanner_platforms
      scanIntervalHours = var.scan_interval_hours
    }))
  }

  freeform_tags = var.common_tags
}
