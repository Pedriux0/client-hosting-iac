//OUTPUTS FOR THE PERSISTENT LAYER - consumed by ephemeral/ via terraform_remote_state

output "vpc_id" {
  value = aws_vpc.main.id
}

// Private subnets ( No internet "NAT")
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

//Public subnets - internet facing
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "web_security_group_id" {
  value = aws_security_group.web.id
}

output "kms_key_arn" {
  value = aws_kms_key.rds.arn
}

output "target_group_arn" {
  value = aws_alb_target_group.web.arn
}

output "alb_dns_name" {
  description = "Point the app CNAME at this"
  value       = aws_alb.main.dns_name
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
