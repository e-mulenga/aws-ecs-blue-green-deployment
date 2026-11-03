variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "name_prefix" {
  type = string
}

variable "enable_sqs" {
  type    = bool
  default = true
}

variable "create_endpoints" {
  description = "Create endpoints the VPC lacks. false = only consume what exists."
  type        = bool
  default     = true
}
