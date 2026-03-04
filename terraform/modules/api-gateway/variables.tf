variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "subnet_id" {
  description = "Subnet OCID for the API Gateway"
  type        = string
}

variable "event_task_scheduler_function_id" {
  description = "OCID of the event-task-scheduler function"
  type        = string
}

variable "oci_sdk_wrapper_function_id" {
  description = "OCID of the oci-sdk-wrapper function"
  type        = string
}

variable "auth_function_id" {
  description = "OCID of the authorizer function (uses qflow-api for token validation)"
  type        = string
}

variable "rate_limit_rps" {
  description = "Rate limit in requests per second"
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
