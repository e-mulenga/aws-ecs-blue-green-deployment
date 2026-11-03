output "created_gateway_endpoints" {
  value = sort(keys(aws_vpc_endpoint.gateway))
}

output "created_interface_endpoints" {
  value = sort(keys(aws_vpc_endpoint.interface))
}

output "reused_endpoints" {
  value = []
}
