data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  cluster_name  = "${local.name_prefix}-cluster"
  service_name  = "${local.name_prefix}-service"
  family        = "${local.name_prefix}-task"
  cd_app_name   = local.name_prefix
  cd_group_name = "${local.name_prefix}-dg"

  # Landing Zone shared-applications repository: registry host / path
  ecr_repository_name = replace(local.app_image_repo, "/^[^/]+\\//", "")
  image               = "${local.app_image_repo}:${var.image_tag}"

  app_fqdn = "${var.app_subdomain}.${local.route53_domain}"

  table_cmk = local.use_cmk ? local.kms_arn["dynamodb"] : null
  sqs_cmk   = local.use_cmk ? local.kms_arn["sqs"] : null
}

# ---- Data: the only stateful resource this workload owns
module "dynamodb" {
  source = "./modules/dynamodb"

  name                = "${local.name_prefix}-urls"
  deletion_protection = var.enable_deletion_protection
  kms_key_arn         = local.table_cmk
  replica_region      = var.enable_dynamodb_replication && !local.is_dr ? var.dr_region : null
  replica_kms_key_arn = var.dr_dynamodb_kms_key_arn

  depends_on = [terraform_data.landing_zone_contract]
}

# ---- Click-event queue (optional) with a dead-letter queue
resource "aws_sqs_queue" "click_events_dlq" {
  count = var.enable_click_events_queue ? 1 : 0

  name                      = "${local.name_prefix}-click-events-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = local.sqs_cmk == null ? true : null
  kms_master_key_id         = local.sqs_cmk
}

resource "aws_sqs_queue" "click_events" {
  count = var.enable_click_events_queue ? 1 : 0

  name                      = "${local.name_prefix}-click-events"
  sqs_managed_sse_enabled   = local.sqs_cmk == null ? true : null
  kms_master_key_id         = local.sqs_cmk
  message_retention_seconds = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.click_events_dlq[0].arn
    maxReceiveCount     = 5
  })
}

# ---- Private AWS access for Fargate in the Landing Zone private subnets (no NAT there)
module "endpoints" {
  source = "./modules/endpoints"

  vpc_id             = local.vpc_id
  vpc_cidr           = local.vpc_cidr
  region             = local.active_region
  private_subnet_ids = local.private_subnet_ids
  name_prefix        = local.name_prefix
  enable_sqs         = var.enable_click_events_queue
  create_endpoints   = var.create_workload_endpoints

  depends_on = [terraform_data.landing_zone_contract]
}

module "iam" {
  source = "./modules/iam"

  name_prefix              = local.name_prefix
  environment              = var.environment
  region                   = local.active_region
  account_id               = local.account_id
  partition                = local.partition
  github_repo              = var.github_repo
  github_oidc_provider_arn = local.github_oidc_arn
  ecr_repository_name      = local.ecr_repository_name
  cluster_name             = local.cluster_name
  service_name             = local.service_name
  codedeploy_app_name      = local.cd_app_name
  codedeploy_group_name    = local.cd_group_name
  dynamodb_table_arn       = module.dynamodb.arn
  dynamodb_kms_key_arn     = local.table_cmk
  sqs_queue_arn            = var.enable_click_events_queue ? aws_sqs_queue.click_events[0].arn : null
}

module "alb" {
  source = "./modules/alb"

  name_prefix         = local.name_prefix
  vpc_id              = local.vpc_id
  public_subnet_ids   = local.public_subnet_ids
  certificate_arn     = local.acm_certificate # Landing Zone certificate, never created here
  target_port         = var.container_port
  deletion_protection = var.enable_deletion_protection
  access_logs_bucket  = var.alb_access_logs_bucket

  depends_on = [terraform_data.landing_zone_contract]
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix           = local.name_prefix
  region                = local.active_region
  vpc_id                = local.vpc_id
  vpc_cidr              = local.vpc_cidr
  private_subnet_ids    = local.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.blue_target_group_arn
  cluster_name          = local.cluster_name
  service_name          = local.service_name
  family                = local.family
  image                 = local.image
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arn
  container_port        = var.container_port
  cpu                   = var.task_cpu
  memory                = var.task_memory
  desired_count         = var.desired_count
  container_insights    = var.container_insights
  log_retention_days    = var.log_retention_days

  environment_variables = merge(
    {
      TABLE_NAME     = module.dynamodb.name
      AWS_REGION     = local.active_region
      BLUEGREEN_PORT = tostring(var.container_port)
      BASE_URL       = "https://${local.app_fqdn}"
    },
    var.enable_click_events_queue ? { SQS_QUEUE_URL = aws_sqs_queue.click_events[0].url } : {}
  )

  depends_on = [module.endpoints, module.alb]
}

# ALB may reach the tasks on the app port only
resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = module.alb.security_group_id
  description                  = "App port to the Fargate tasks"
  referenced_security_group_id = module.ecs.security_group_id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

# Rollback alarm: target 5xx on the production listener's target groups
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "${local.name_prefix}-target-5xx"
  alarm_description   = "Target 5xx responses; stops and rolls back a CodeDeploy deployment"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.alarm_5xx_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
  }

  # Landing Zone SNS topic. Its topic policy must allow cloudwatch.amazonaws.com to publish.
  alarm_actions = local.alerts_topic_arn != null ? [local.alerts_topic_arn] : []
}

module "codedeploy" {
  source = "./modules/codedeploy"

  app_name                 = local.cd_app_name
  group_name               = local.cd_group_name
  cluster_name             = module.ecs.cluster_name
  service_name             = module.ecs.service_name
  service_role_arn         = module.iam.codedeploy_role_arn
  listener_arn             = module.alb.https_listener_arn
  blue_target_group_name   = module.alb.blue_target_group_name
  green_target_group_name  = module.alb.green_target_group_name
  deployment_config_name   = var.deployment_config_name
  termination_wait_minutes = var.termination_wait_minutes
  alarm_names              = [aws_cloudwatch_metric_alarm.target_5xx.alarm_name]
}

module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "./modules/waf"

  name_prefix        = local.name_prefix
  alb_arn            = module.alb.arn
  rate_limit         = var.waf_rate_limit
  log_retention_days = var.log_retention_days
}

# ---- DNS: alias record in the Landing Zone hosted zone (the zone and certificate are the Landing Zone's)
resource "aws_route53_record" "app" {
  count = var.create_dns_record ? 1 : 0

  zone_id = local.route53_zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_budgets_budget" "workload" {
  count = var.monthly_budget_usd > 0 ? 1 : 0

  name         = "${local.name_prefix}-bluegreen"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$aws-ecs-blue-green-deployment"]
  }

  dynamic "notification" {
    for_each = length(var.budget_emails) > 0 ? [80, 100] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.budget_emails
    }
  }
}
