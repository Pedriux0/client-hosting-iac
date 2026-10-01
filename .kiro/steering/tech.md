# Technical Standards

## Stack
- Terraform >= 1.10, AWS provider ~> 5.0, region us-east-1
- State: S3 bucket client-hosting-tfstate-eb6b3ade with native locking
  (use_lockfile = true). No DynamoDB.

## Security rules
- Security groups reference other security groups by ID
  (referenced_security_group_id), never broad CIDR, except the ALB's
  public 80/443 ingress.
- Use aws_vpc_security_group_ingress_rule / egress_rule resources, one rule
  per resource, each with a description.
- Encrypt at rest with the customer-managed KMS key.
- Passwords are generated with random_password and stored in Secrets Manager.
  Never hardcode secrets, never put them in .tfvars.
- RDS is never publicly accessible.

## Cost rules
- Free-tier sizes only: t3.micro, db.t3.micro.
- NAT gateway stays disabled by default (enable_nat_gateway = false).
- RDS backup_retention_period = 1 (free tier maximum).
- Secrets Manager recovery_window_in_days = 0 so destroy/recreate works.

## Conventions
- All names use "${var.project_name}-<thing>".
- Every resource gets a Name tag; provider default_tags adds Project and ManagedBy.
- Run terraform fmt and terraform validate after every change.

## Hard safety rules for the agent
- NEVER run terraform apply or terraform destroy. Only fmt, validate, init, plan.
  I run apply and destroy myself after reading the plan.
- NEVER touch the bootstrap/ directory.
- NEVER commit .tfstate, .tfvars, or .terraform/.
- If a plan shows any destroy, stop and tell me before continuing.