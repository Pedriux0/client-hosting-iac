//OUTPUTS FOR THE INFRA (client-hosting-iac)

output "vpc_id" {
  value = aws_vpc.main.id
}
//Public subnets - internet facing
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

// Private subnets ( No internet "NAT")

output "private_subnets_ids" {
  value = aws_subnet.private[*].id
}
