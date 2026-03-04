variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "tenancy_id" {
  description = "The OCID of the scanning tenancy"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet OCIDs for the Function Application"
  type        = list(string)
}

variable "scanner_subnet_id" {
  description = "Subnet OCID for scanner compute instances"
  type        = string
}

variable "scanner_nsg_id" {
  description = "NSG OCID for scanner compute instances"
  type        = string
}

variable "scanner_image_id" {
  description = "Custom image OCID for scanner instances"
  type        = string
  default     = ""
}

variable "qflow_endpoint" {
  description = "qflow API endpoint URL"
  type        = string
}

variable "vault_id" {
  description = "OCID of the OCI Vault"
  type        = string
}

variable "master_key_id" {
  description = "OCID of the master encryption key"
  type        = string
}

variable "ocir_registry" {
  description = "OCIR registry path (e.g., iad.ocir.io/namespace)"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag for functions"
  type        = string
  default     = "latest"
}

variable "log_level" {
  description = "Log level for functions"
  type        = string
  default     = "INFO"
}

variable "common_tags" {
  description = "Common freeform tags"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
