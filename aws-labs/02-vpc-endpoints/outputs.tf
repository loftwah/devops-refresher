output "endpoint_sg_id" {
  value       = aws_security_group.endpoints.id
  description = "Security group used by interface endpoints"
}

output "s3_gateway_endpoint_id" {
  value       = try(aws_vpc_endpoint.s3[0].id, null)
  description = "S3 gateway endpoint ID (if enabled)"
}

output "interface_endpoint_ids" {
  value       = { for k, v in aws_vpc_endpoint.interfaces : k => v.id }
  description = "Map of interface endpoint IDs by service suffix"
}

