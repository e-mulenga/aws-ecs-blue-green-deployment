output "app_url" {
  value = "https://${local.app_fqdn}"
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "name_prefix" {
  value = local.name_prefix
}

output "region" {
  value = local.active_region
}

output "image_repository" {
  description = "Landing Zone ECR repository the image is pushed to"
  value       = local.app_image_repo
}

output "image_tag" {
  value = var.image_tag
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "task_definition_family" {
  value = module.ecs.task_definition_family
}

output "container_name" {
  value = module.ecs.container_name
}

output "container_port" {
  value = var.container_port
}

output "codedeploy_app_name" {
  value = module.codedeploy.app_name
}

output "codedeploy_deployment_group" {
  value = module.codedeploy.group_name
}

output "github_deploy_role_arn" {
  description = "Set as the AWS_ROLE_ARN secret of the GitHub environment (not a credential)"
  value       = module.iam.github_deploy_role_arn
}

output "dynamodb_table_name" {
  value = module.dynamodb.name
}

output "click_events_queue_url" {
  value = try(aws_sqs_queue.click_events[0].url, null)
}

output "endpoints_created" {
  value = concat(module.endpoints.created_gateway_endpoints, module.endpoints.created_interface_endpoints)
}

output "endpoints_reused" {
  value = module.endpoints.reused_endpoints
}
