variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "qflow_token" {
  description = "qflow subscription token"
  type        = string
  sensitive   = true
}

variable "scanner_platforms" {
  description = "Scanner platforms to support"
  type        = list(string)
  default     = ["LINUX", "WINDOWS"]
}

variable "scan_interval_hours" {
  description = "Default scan interval in hours"
  type        = number
  default     = 24
}

variable "common_tags" {
  description = "Common freeform tags"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
