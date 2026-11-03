variable "app_name" {
  type = string
}

variable "group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "service_role_arn" {
  type = string
}

variable "listener_arn" {
  type = string
}

variable "blue_target_group_name" {
  type = string
}

variable "green_target_group_name" {
  type = string
}

variable "deployment_config_name" {
  description = "CodeDeployDefault.ECSAllAtOnce (dev) or ECSCanary10Percent5Minutes / ECSLinear10PercentEvery1Minutes (stage, prod)"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"
}

variable "termination_wait_minutes" {
  type    = number
  default = 5
}

variable "alarm_names" {
  description = "CloudWatch alarms that stop and roll back a deployment"
  type        = list(string)
  default     = []
}
