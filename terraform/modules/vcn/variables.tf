variable "compartment_id" {
  description = "The OCID of the compartment"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the private scanner subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (API Gateway)"
  type        = string
  default     = "10.10.2.0/24"
}

variable "create_public_subnet" {
  description = "Whether to create a public subnet for API Gateway"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common freeform tags"
  type        = map(string)
  default = {
    App = "snapshot-scanner"
  }
}
