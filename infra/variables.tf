variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Resourcs prefix"
  type        = string
  default     = "client-hosting"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
#The cost of the VPC is around 32 CAD - monthly 
variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for private subnets"
  type        = bool
  default     = false
}

#Enviroments 
variable "environments" {
  description = "List of environments to create"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}