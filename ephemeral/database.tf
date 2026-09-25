// Subnet group // This tells the RDS in which subnets it may be in

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.terraform_remote_state.persistent.outputs.private_subnet_ids

  tags = { Nmae = "${var.project_name} -db-subnet-group" }
}
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = data.terraform_remote_state.persistent.outputs.kms_key_arn

  db_name  = var.db_name
  username = var.db_username
  password = data.terraform_remote_state.persistent.outputs.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [data.terraform_remote_state.persistent.outputs.db_security_group_id]
  publicly_accessible    = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = { Name = "${var.project_name}-db" }
}
