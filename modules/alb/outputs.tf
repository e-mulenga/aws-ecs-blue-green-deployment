output "security_group_id" {
  value = aws_security_group.alb.id
}

output "arn" {
  value = aws_lb.this.arn
}

output "arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "zone_id" {
  value = aws_lb.this.zone_id
}

output "blue_target_group_arn" {
  value = aws_lb_target_group.blue.arn
}

output "blue_target_group_name" {
  value = aws_lb_target_group.blue.name
}

output "blue_target_group_arn_suffix" {
  value = aws_lb_target_group.blue.arn_suffix
}

output "green_target_group_name" {
  value = aws_lb_target_group.green.name
}

output "green_target_group_arn_suffix" {
  value = aws_lb_target_group.green.arn_suffix
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}
