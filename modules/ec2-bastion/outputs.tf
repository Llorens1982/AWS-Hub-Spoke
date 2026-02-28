output "instance_id" {
  description = "Bastion EC2 instance ID — connect via: aws ssm start-session --target <instance_id>"
  value       = aws_instance.bastion.id
}

output "private_ip" {
  value = aws_instance.bastion.private_ip
}
