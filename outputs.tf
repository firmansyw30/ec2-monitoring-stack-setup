output "spot_request_id" {
  description = "Spot Instance Request ID"
  value       = aws_spot_instance_request.monitoring.id
}

output "instance_id" {
  description = "Fulfilled EC2 Instance ID"
  value       = aws_spot_instance_request.monitoring.spot_instance_id
}

output "public_ip" {
  description = "Public IP of the monitoring instance"
  value       = aws_spot_instance_request.monitoring.public_ip
}
