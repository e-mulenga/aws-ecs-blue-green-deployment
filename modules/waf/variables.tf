variable "name_prefix" {
  type = string
}

variable "alb_arn" {
  type = string
}

variable "rate_limit" {
  description = "Requests per 5 minutes per IP before blocking"
  type        = number
  default     = 1000
}

variable "log_retention_days" {
  type    = number
  default = 7
}
