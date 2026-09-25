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

#Instances class for the RDS
variable "db_instance_class" {
  description = "RDS instances class"
  type        = string
  default     = "db.t3.micro"
}

#Db name

variable "db_name" {
  description = "Database Name"
  type        = string
  default     = "clienthosting"
}

#Db username

variable "db_username" {
  description = "db username"
  type        = string
  default     = "dbadmin"
}
