variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "qflow_api_function_id" {
  description = "OCID of the qflow-api function"
  type        = string
}

variable "resource_inventory_stream_id" {
  description = "Stream OCID for resource_inventory table changes"
  type        = string
  default     = ""
}

variable "scan_status_stream_id" {
  description = "Stream OCID for scan_status table changes"
  type        = string
  default     = ""
}

variable "event_logs_stream_id" {
  description = "Stream OCID for event_logs table changes"
  type        = string
  default     = ""
}

variable "discovery_task_stream_id" {
  description = "Stream OCID for discovery_task table changes"
  type        = string
  default     = ""
}

variable "app_config_stream_id" {
  description = "Stream OCID for app_config table changes"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common freeform tags"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
