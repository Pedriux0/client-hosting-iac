// Customer- managaged key for encryption 

resource "aws_kms_key" "rds" {
  description             = "Encryption for RDS ${var.project_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = { Name = "${var.project_name}-rds-key" }
}


resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}--rds"
  target_key_id = aws_kms_key.rds.key_id
}

// GENERATED PASSWORD no written in the variables

resource "random_password" "db" {
  length  = 32
  special = true
  //RDS
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}/db/credentials"
  description             = "RDS master credentials"
  kms_key_id              = aws_kms_key.rds.arn
  recovery_window_in_days = 0

  tags = { Name = "${var.project_name}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "mysql"
    host     = aws_db_instance.main.address
    port     = 3306
    dbname   = var.db_name
  })
}

// Subnet group // This tells the RDS in which subnets it may be in 

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

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
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = { Name = "${var.project_name}-db" }
}