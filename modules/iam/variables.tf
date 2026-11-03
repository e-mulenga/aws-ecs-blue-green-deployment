variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "partition" {
  type    = string
  default = "aws"
}

variable "github_repo" {
  description = "owner/name of the GitHub repository allowed to deploy"
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "Landing Zone GitHub OIDC provider"
  type        = string
}

variable "ecr_repository_name" {
  description = "Landing Zone ECR repository name (path after the registry host)"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "codedeploy_app_name" {
  type = string
}

variable "codedeploy_group_name" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "dynamodb_kms_key_arn" {
  type    = string
  default = null
}

variable "sqs_queue_arn" {
  type    = string
  default = null
}
