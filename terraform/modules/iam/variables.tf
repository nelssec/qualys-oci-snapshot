variable "tenancy_id" {
  description = "The OCID of the scanning tenancy"
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment for scanner resources"
  type        = string
}

variable "target_tenancy_ids" {
  description = "List of target tenancy OCIDs for cross-tenancy policies"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common freeform tags to apply to all resources"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
