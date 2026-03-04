variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "table_read_units" {
  description = "Max read units for each table"
  type        = number
  default     = 50
}

variable "table_write_units" {
  description = "Max write units for each table"
  type        = number
  default     = 50
}

variable "table_storage_gbs" {
  description = "Max storage in GBs for each table"
  type        = number
  default     = 25
}

variable "common_tags" {
  description = "Common freeform tags"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
