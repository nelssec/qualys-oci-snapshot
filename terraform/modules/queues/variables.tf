variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "max_concurrent_backups" {
  description = "Max concurrent backups per region (OCI limit is 10)"
  type        = number
  default     = 10
}

variable "single_region_concurrency" {
  description = "Max concurrent scanner instances per region"
  type        = number
  default     = 10
}

variable "common_tags" {
  description = "Common freeform tags"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
