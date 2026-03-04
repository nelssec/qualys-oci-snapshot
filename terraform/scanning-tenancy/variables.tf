# --- Required Variables ---

variable "tenancy_id" {
  description = "OCID of the scanning tenancy"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment for all scanner resources"
  type        = string
}

variable "region" {
  description = "Primary OCI region (e.g., us-ashburn-1)"
  type        = string
}

variable "qflow_token" {
  description = "qflow subscription token"
  type        = string
  sensitive   = true
}

variable "qflow_endpoint" {
  description = "qflow API Gateway URL"
  type        = string
}

variable "ocir_registry" {
  description = "OCIR registry path (e.g., iad.ocir.io/namespace)"
  type        = string
}

variable "object_storage_namespace" {
  description = "Object Storage namespace for the tenancy"
  type        = string
}

# --- Target Tenancy Configuration ---

variable "target_tenancy_ids" {
  description = "List of target tenancy OCIDs for cross-tenancy scanning"
  type        = list(string)
  default     = []
}

# --- Scanner Configuration ---

variable "scanner_image_id" {
  description = "Custom image OCID for scanner instances"
  type        = string
  default     = ""
}

variable "single_region_concurrency" {
  description = "Number of scanner instances per region (1-50)"
  type        = number
  default     = 10
  validation {
    condition     = var.single_region_concurrency >= 1 && var.single_region_concurrency <= 50
    error_message = "Must be between 1 and 50."
  }
}

variable "region_concurrency" {
  description = "Number of regions to scan concurrently (1-5)"
  type        = number
  default     = 2
  validation {
    condition     = var.region_concurrency >= 1 && var.region_concurrency <= 5
    error_message = "Must be between 1 and 5."
  }
}

variable "scan_interval_hours" {
  description = "Snapshot refresh interval in hours (24-168)"
  type        = number
  default     = 24
  validation {
    condition     = var.scan_interval_hours >= 24 && var.scan_interval_hours <= 168
    error_message = "Must be between 24 and 168."
  }
}

variable "events_batch_window_minutes" {
  description = "Batch trigger scan duration in minutes (5-720)"
  type        = number
  default     = 10
}

variable "poll_retry_interval_minutes" {
  description = "Retry discovery interval in minutes (15-720)"
  type        = number
  default     = 240
}

# --- Scan Features ---

variable "swca_enabled" {
  description = "Enable software composition analysis"
  type        = bool
  default     = false
}

variable "secret_scan_enabled" {
  description = "Enable secret scanning"
  type        = bool
  default     = false
}

variable "image_scan_enabled" {
  description = "Enable custom image scanning"
  type        = bool
  default     = false
}

variable "scan_sampling_enabled" {
  description = "Enable scan sampling"
  type        = bool
  default     = false
}

variable "sampling_percentage" {
  description = "Percentage of instances to sample (1-50)"
  type        = number
  default     = 10
}

# --- Tag Filters ---

variable "must_have_tags" {
  description = "Comma-separated tagKey=tagValue pairs - all must be present"
  type        = string
  default     = ""
}

variable "at_least_one_tags" {
  description = "Comma-separated tagKey=tagValue pairs - any one sufficient"
  type        = string
  default     = ""
}

variable "none_in_the_list_tags" {
  description = "Comma-separated tagKey=tagValue pairs - exclude if any match"
  type        = string
  default     = ""
}

variable "none_on_volume_tags" {
  description = "Comma-separated tagKey=tagValue pairs - exclude volumes if any match"
  type        = string
  default     = ""
}

# --- Network Configuration ---

variable "vcn_cidr" {
  description = "CIDR block for the scanner VCN"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the private scanner subnet"
  type        = string
  default     = "10.10.1.0/24"
}

# --- Optional ---

variable "image_tag" {
  description = "Docker image tag for functions"
  type        = string
  default     = "latest"
}

variable "log_level" {
  description = "Log level for functions (DEBUG, INFO, WARN, ERROR)"
  type        = string
  default     = "INFO"
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common freeform tags for all resources"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
