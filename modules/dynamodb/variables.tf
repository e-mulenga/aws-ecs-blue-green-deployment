variable "name" {
  type = string
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "point_in_time_recovery" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  description = "Landing Zone CMK ARN. null = AWS-owned encryption (dev/test)."
  type        = string
  default     = null
}

variable "replica_region" {
  description = "Region for a global-table replica (DR). null disables replication."
  type        = string
  default     = null
}

variable "replica_kms_key_arn" {
  description = "CMK in the replica region. Required when kms_key_arn is set and a replica exists; the Landing Zone does not export eu-west-1 keys."
  type        = string
  default     = null
}
