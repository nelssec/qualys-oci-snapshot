output "vault_id" {
  description = "OCID of the vault"
  value       = oci_kms_vault.scanner_vault.id
}

output "vault_management_endpoint" {
  description = "Management endpoint of the vault"
  value       = oci_kms_vault.scanner_vault.management_endpoint
}

output "vault_crypto_endpoint" {
  description = "Crypto endpoint of the vault"
  value       = oci_kms_vault.scanner_vault.crypto_endpoint
}

output "master_key_id" {
  description = "OCID of the master encryption key"
  value       = oci_kms_key.master_key.id
}

output "qflow_token_secret_id" {
  description = "OCID of the qflow token secret"
  value       = oci_vault_secret.qflow_token.id
}

output "scanner_config_secret_id" {
  description = "OCID of the scanner config secret"
  value       = oci_vault_secret.scanner_config.id
}
