output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}
output "shared_services_sg_id" {
  value = aws_security_group.shared_services.id
}
output "app_sg_id" {
  value = aws_security_group.app.id
}
