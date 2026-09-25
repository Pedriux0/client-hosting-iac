// GENERATED PASSWORD no written in the variables

resource "random_password" "db" {
  length  = 32
  special = true
  //RDS
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

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
    dbname   = var.db_name
  })
}
