variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "function_application_id" {
  description = "OCID of the Function Application"
  type        = string
}

variable "api_gateway_id" {
  description = "OCID of the API Gateway"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
}

variable "function_error_threshold" {
  description = "Function error count threshold for alarm"
  type        = number
  default     = 5
}

variable "queue_depth_threshold" {
  description = "Queue depth threshold for alarm"
  type        = number
  default     = 100
}

variable "alarm_notification_topic_ids" {
  description = "Notification topic OCIDs for alarm destinations"
  type        = list(string)
  default     = []
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
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
