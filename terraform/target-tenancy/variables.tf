variable "tenancy_id" {
  description = "OCID of this target tenancy"
  type        = string
}

variable "region" {
  description = "Primary OCI region"
  type        = string
}

variable "compartment_id" {
  description = "Compartment OCID for event-forwarder resources"
  type        = string
}

variable "scanning_tenancy_id" {
  description = "OCID of the scanning tenancy"
  type        = string
}

variable "scanning_dynamic_group_id" {
  description = "OCID of the scanner functions dynamic group from the scanning tenancy"
  type        = string
}

variable "scanning_api_gateway_endpoint" {
  description = "API Gateway /events endpoint URL from the scanning tenancy"
  type        = string
}

variable "qflow_token" {
  description = "qflow subscription token (API key portion used for auth)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "event_based_scan" {
  description = "Enable event-based scanning (instance launch triggers)"
  type        = bool
  default     = true
}

variable "target_regions" {
  description = "Regions to deploy event rules in"
  type        = list(string)
  default     = []
}

variable "event_forwarder_ocir_image" {
  description = "OCIR image for the event-forwarder function"
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
