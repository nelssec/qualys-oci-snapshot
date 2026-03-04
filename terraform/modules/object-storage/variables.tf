variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "object_storage_namespace" {
  description = "Object Storage namespace"
  type        = string
}

variable "region" {
  description = "OCI region identifier"
  type        = string
}

variable "scan_data_retention_days" {
  description = "Number of days to retain scan data"
  type        = number
  default     = 90
}

variable "common_tags" {
  description = "Common freeform tags"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
