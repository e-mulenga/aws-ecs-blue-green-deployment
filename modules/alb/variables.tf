variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {
  description = "Landing Zone ACM certificate (never created here)"
  type        = string
}

variable "target_port" {
  type = number
}

variable "health_check_path" {
  type    = string
  default = "/healthz"
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "access_logs_bucket" {
  description = "Same-region S3 bucket for ALB access logs. null = off."
  type        = string
  default     = null
}
