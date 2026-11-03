output "app_name" {
  value = aws_codedeploy_app.this.name
}

output "group_name" {
  value = aws_codedeploy_deployment_group.this.deployment_group_name
}
