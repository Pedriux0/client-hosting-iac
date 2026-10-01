# Repository Structure

bootstrap/   S3 state backend. Never modified. Own state key.
persistent/  Long-lived layer: VPC, subnets, IGW, route tables, security
             groups, KMS key, Secrets Manager, ALB, target group, listeners,
             ACM certificate. State key: persistent/terraform.tfstate
ephemeral/   Disposable layer: RDS now, EC2/ASG later. Destroyed when idle.
             Reads persistent outputs via terraform_remote_state.
             State key: ephemeral/terraform.tfstate
infra/       DEPRECATED. Being removed. Do not edit.

## Why the split
Resources have different lifecycles. KMS keys and secrets have 7-day deletion
windows and break destroy/recreate; the ALB DNS name changes on recreate and
breaks the manual DNS CNAME. Those live in persistent. Costly compute lives
in ephemeral.

## Docs
- PHASES.md: build sequence and status
- DECISIONS.md: every tradeoff, constraint, and lesson learned
When a spec is finished, add its decisions to DECISIONS.md.