variable "github_repo" {
  description = "owner/name of the GitHub repository allowed to deploy through OIDC"
  type        = string
  default     = "your-github-repo-name"
}

variable "app_subdomain" {
  description = "Host name label under the Landing Zone Route 53 domain (for example bluegreen -> bluegreen.<domain>). The Landing Zone ACM certificate must cover the resulting name."
  type        = string
  default     = "bluegreen"
}

variable "create_dns_record" {
  description = "Create the alias record in the Landing Zone hosted zone. Leave false for a DR deployment until failover."
  type        = bool
  default     = true
}

variable "container_port" {
  type    = number
  default = 5320
}

variable "image_tag" {
  description = "Tag in the Landing Zone shared-applications repository. Images are tagged url-shortener-<version> so the shared repo stays unambiguous."
  type        = string
  default     = "url-shortener-latest"
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "deployment_config_name" {
  description = "CodeDeploy traffic shifting: CodeDeployDefault.ECSAllAtOnce (dev), CodeDeployDefault.ECSCanary10Percent5Minutes (stage/prod)"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"
}

variable "termination_wait_minutes" {
  description = "Minutes the blue task set is kept after a successful deployment (instant rollback window)"
  type        = number
  default     = 5
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "waf_rate_limit" {
  type    = number
  default = 1000
}

variable "enable_click_events_queue" {
  description = "Create the SQS queue (with DLQ) the app publishes click events to"
  type        = bool
  default     = true
}

variable "enable_dynamodb_replication" {
  description = "Global-table replica in the DR region (eu-west-1)"
  type        = bool
  default     = false
}

variable "create_workload_endpoints" {
  description = "Create the VPC endpoints this workload needs that the VPC lacks (the Landing Zone currently provides none)"
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Deletion protection on the ALB and DynamoDB table (required in prod)"
  type        = bool
  default     = false
}

variable "container_insights" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket in the SAME region as the ALB for access logs. The Landing Zone access-logs bucket is in us-east-1 and cannot be used. null = off."
  type        = string
  default     = null
}

variable "alarm_5xx_threshold" {
  description = "Target 5xx responses per minute that stop and roll back a deployment"
  type        = number
  default     = 10
}

variable "monthly_budget_usd" {
  description = "Workload monthly cost budget (USD). 0 disables."
  type        = number
  default     = 0
}

variable "budget_emails" {
  description = "Budget notification recipients. Supply at apply time; never commit addresses."
  type        = list(string)
  default     = []
}

variable "dr_dynamodb_kms_key_arn" {
  description = "CMK in eu-west-1 for the DynamoDB replica. Needed in stage/prod when replication is on and a Landing Zone CMK encrypts the table; the Landing Zone exports no eu-west-1 keys."
  type        = string
  default     = null
}
