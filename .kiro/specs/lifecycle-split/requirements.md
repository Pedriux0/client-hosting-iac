# Requirements Document

## Introduction

The `client-hosting-iac` Terraform project is mid-refactor from a single `infra/`
directory into two independent state layers: a long-lived `persistent/` layer and a
disposable `ephemeral/` layer. Configuration files have already been copied between
directories, but the wiring between the two layers is incomplete and the stale `infra/`
directory still holds duplicate resources.

This feature completes the split. The `persistent/` layer owns long-lived resources
(VPC, subnets, security groups, KMS key, Secrets Manager secret, ALB, target group,
ACM) and publishes their identifiers as outputs. The `ephemeral/` layer owns the
disposable RDS database and consumes the persistent layer's outputs through a
`terraform_remote_state` data source instead of referencing resources directly. Each
layer stores its own state in the shared S3 backend under a distinct key, using native
S3 locking (no DynamoDB).

Because the ephemeral layer depends on the persistent layer's remote state, the layers
have a strict apply and destroy order. This document also captures the safety
constraints under which the change is made: the agent may run only read-only or
plan-level Terraform commands, must never apply or destroy, and must halt if any plan
proposes a destroy.

The requirements below describe the desired end state. Where the repository already
satisfies a requirement, the requirement asserts that end state so it can be verified;
it does not imply the work is unfinished.

## Glossary

- **Persistent_Layer**: The Terraform root module in the `persistent/` directory,
  owning long-lived resources and publishing outputs. State key `persistent/terraform.tfstate`.
- **Ephemeral_Layer**: The Terraform root module in the `ephemeral/` directory, owning
  disposable resources (the RDS database) and consuming Persistent_Layer outputs. State
  key `ephemeral/terraform.tfstate`.
- **Infra_Directory**: The legacy `infra/` directory holding stale duplicate resources,
  to be removed after it has been destroyed.
- **State_Bucket**: The S3 bucket `client-hosting-tfstate-eb6b3ade` used as the Terraform
  backend, configured with native S3 locking (`use_lockfile = true`) in region `us-east-1`.
- **Remote_State_Source**: The `terraform_remote_state` data source named `persistent`
  declared in the Ephemeral_Layer, reading the Persistent_Layer state from State_Bucket.
- **DB_Secret**: The Secrets Manager secret `aws_secretsmanager_secret.db` and its
  version `aws_secretsmanager_secret_version.db`, storing RDS master credentials as JSON.
- **Agent**: The automated assistant executing Terraform commands on the user's behalf.
- **Operator**: The human user who runs apply, destroy, and manual filesystem removal.

## Requirements

### Requirement 1: Secrets and encryption resources reside in the persistent layer

**User Story:** As an infrastructure engineer, I want the database password, KMS key, KMS alias, and Secrets Manager secret to live in the persistent layer, so that credentials and encryption keys survive the destruction of the disposable database layer.

#### Acceptance Criteria

1. THE Persistent_Layer SHALL define the resource `random_password.db` in `persistent/secrets.tf`.
2. THE Persistent_Layer SHALL define the resource `aws_kms_key.rds` in `persistent/secrets.tf`.
3. THE Persistent_Layer SHALL define the resource `aws_kms_alias.rds` in `persistent/secrets.tf`.
4. THE Persistent_Layer SHALL define the resource `aws_secretsmanager_secret.db` in `persistent/secrets.tf`.
5. THE Persistent_Layer SHALL define the resource `aws_secretsmanager_secret_version.db` in `persistent/secrets.tf`.
6. THE Persistent_Layer SHALL set `recovery_window_in_days` to `0` on `aws_secretsmanager_secret.db`.
7. WHERE the DB_Secret version stores its `secret_string` JSON, THE Persistent_Layer SHALL include exactly the keys `username`, `password`, `engine`, and `dbname`.
8. THE Persistent_Layer SHALL exclude the keys `host` and `port` from the DB_Secret `secret_string` JSON.
9. THE Ephemeral_Layer SHALL NOT define `random_password.db`, `aws_kms_key.rds`, `aws_kms_alias.rds`, `aws_secretsmanager_secret.db`, or `aws_secretsmanager_secret_version.db`.
10. WHEN the Ephemeral_Layer is destroyed and reapplied, THE Persistent_Layer SHALL retain `random_password.db.result`, `aws_kms_key.rds`, and the DB_Secret `secret_string` value unchanged.
11. WHILE the Ephemeral_Layer is applied, THE Ephemeral_Layer SHALL resolve the DB_Secret credentials and KMS key ARN through the Remote_State_Source rather than by defining those resources locally.

### Requirement 2: Persistent layer publishes consumable outputs

**User Story:** As an infrastructure engineer, I want the persistent layer to expose the
identifiers the ephemeral layer needs, so that the ephemeral layer can reference them through
remote state.

#### Acceptance Criteria

1. THE Persistent_Layer SHALL define an output named `vpc_id`.
2. THE Persistent_Layer SHALL define an output named `private_subnet_ids`.
3. THE Persistent_Layer SHALL define an output named `public_subnet_ids`.
4. THE Persistent_Layer SHALL define an output named `db_security_group_id`.
5. THE Persistent_Layer SHALL define an output named `web_security_group_id`.
6. THE Persistent_Layer SHALL define an output named `kms_key_arn`.
7. THE Persistent_Layer SHALL define an output named `target_group_arn`.
8. THE Persistent_Layer SHALL define an output named `alb_dns_name`.
9. THE Persistent_Layer SHALL define an output named `db_password` with the attribute `sensitive = true`.

### Requirement 3: Persistent layer backend configuration

**User Story:** As an infrastructure engineer, I want the persistent layer to store its state
under a dedicated key in the shared S3 backend, so that its state is isolated from the ephemeral
layer.

#### Acceptance Criteria

1. THE Persistent_Layer SHALL configure an S3 backend using State_Bucket.
2. THE Persistent_Layer SHALL set the backend `key` to `persistent/terraform.tfstate`.
3. THE Persistent_Layer SHALL set the backend `region` to `us-east-1`.
4. THE Persistent_Layer SHALL enable native S3 locking by setting `use_lockfile = true`.
5. THE Persistent_Layer SHALL enable backend encryption by setting `encrypt = true`.

### Requirement 4: Ephemeral layer backend, provider, and remote state configuration

**User Story:** As an infrastructure engineer, I want the ephemeral layer to have its own
backend, matching provider configuration, and a remote state data source, so that it stores
state independently and can read persistent outputs.

#### Acceptance Criteria

1. THE Ephemeral_Layer SHALL configure an S3 backend using State_Bucket.
2. THE Ephemeral_Layer SHALL set the backend `key` to `ephemeral/terraform.tfstate`.
3. THE Ephemeral_Layer SHALL set the backend `region` to `us-east-1`.
4. THE Ephemeral_Layer SHALL enable native S3 locking by setting `use_lockfile = true`.
5. THE Ephemeral_Layer SHALL configure the `hashicorp/aws` provider with the same version constraint and `default_tags` structure used by the Persistent_Layer.
6. THE Ephemeral_Layer SHALL declare a `terraform_remote_state` data source named `persistent`.
7. THE Remote_State_Source SHALL read from State_Bucket using the key `persistent/terraform.tfstate` in region `us-east-1`.

### Requirement 5: Ephemeral database reads dependencies from remote state

**User Story:** As an infrastructure engineer, I want the ephemeral database to obtain its
subnets, security group, KMS key, and password from the persistent layer's remote state, so that
the database layer has no direct dependency on persistent resources.

#### Acceptance Criteria

1. THE Ephemeral_Layer SHALL read private subnet identifiers from `data.terraform_remote_state.persistent.outputs.private_subnet_ids`.
2. THE Ephemeral_Layer SHALL read the database security group identifier from `data.terraform_remote_state.persistent.outputs.db_security_group_id`.
3. THE Ephemeral_Layer SHALL read the KMS key ARN from `data.terraform_remote_state.persistent.outputs.kms_key_arn`.
4. THE Ephemeral_Layer SHALL read the database password from `data.terraform_remote_state.persistent.outputs.db_password`.
5. THE Ephemeral_Layer SHALL reference the subnets, security group, KMS key, and password only through the Remote_State_Source and not through direct resource references.

### Requirement 6: Ephemeral layer variables are scoped to its own usage

**User Story:** As an infrastructure engineer, I want the ephemeral layer to declare only the
variables it uses, so that its configuration stays readable and free of unused inputs.

#### Acceptance Criteria

1. THE Ephemeral_Layer SHALL declare a `variables.tf` file.
2. THE Ephemeral_Layer SHALL declare only variables consumed within the Ephemeral_Layer.
3. WHERE a variable is declared in the Ephemeral_Layer `variables.tf`, THE Ephemeral_Layer SHALL reference that variable within the Ephemeral_Layer configuration.

### Requirement 7: Legacy infra directory removal is a manual operator step

**User Story:** As an infrastructure engineer, I want the removal of the legacy `infra/`
directory documented as a manual step performed after it is destroyed, so that stale duplicate
resources are cleaned up without the agent performing destructive actions.

#### Acceptance Criteria

1. THE requirements SHALL document that removal of the Infra_Directory is performed manually by the Operator.
2. THE requirements SHALL document that the Operator removes the Infra_Directory only after the Infra_Directory resources have been destroyed.
3. THE Agent SHALL NOT delete the Infra_Directory.
4. THE Agent SHALL NOT run `terraform destroy` against the Infra_Directory.

### Requirement 8: Order of operations for apply and destroy

**User Story:** As an infrastructure engineer, I want a defined order for applying and destroying the layers, so that the ephemeral layer's remote state lookup never resolves against missing persistent outputs.

#### Acceptance Criteria

1. WHEN the Operator applies the layers, THE Persistent_Layer SHALL be applied to completion, publishing its outputs to State_Bucket, before the Operator applies the Ephemeral_Layer.
2. WHILE the Persistent_Layer outputs are absent from State_Bucket, THE Ephemeral_Layer SHALL NOT be applied by the Operator.
3. IF the Ephemeral_Layer is applied while the Persistent_Layer outputs are absent from State_Bucket, THEN THE Remote_State_Source SHALL fail to resolve the referenced Persistent_Layer outputs and THE Ephemeral_Layer apply SHALL halt without creating Ephemeral_Layer resources.
4. WHEN the Operator destroys the layers, THE Ephemeral_Layer SHALL be destroyed to completion before the Operator destroys the Persistent_Layer.
5. WHEN the Operator destroys the Infra_Directory resources, THE Infra_Directory resources SHALL be destroyed to completion before the Operator removes the Infra_Directory from the filesystem.

### Requirement 9: Agent safety constraints for Terraform commands

**User Story:** As the project owner, I want the agent restricted to non-destructive Terraform commands and required to halt on any planned destroy, so that no infrastructure or state is changed or lost without operator review.

#### Acceptance Criteria

1. THE Agent SHALL execute only the following Terraform commands: `terraform fmt`, `terraform validate`, `terraform init`, and `terraform plan`.
2. IF the Agent is instructed to run any Terraform command other than `terraform fmt`, `terraform validate`, `terraform init`, or `terraform plan`, THEN THE Agent SHALL refuse to execute the command, SHALL leave all files and remote state unchanged, and SHALL return a message indicating the command is outside the permitted command set.
3. IF the Agent is instructed to run `terraform apply`, THEN THE Agent SHALL refuse to execute the command, SHALL leave all infrastructure and remote state unchanged, and SHALL return a message indicating that apply is prohibited.
4. IF the Agent is instructed to run `terraform destroy`, THEN THE Agent SHALL refuse to execute the command, SHALL leave all infrastructure and remote state unchanged, and SHALL return a message indicating that destroy is prohibited.
5. IF the Agent is instructed to run any Terraform command whose working directory is the `bootstrap/` directory, THEN THE Agent SHALL refuse to execute the command, SHALL leave the State_Bucket and all bootstrap-managed resources unchanged, and SHALL return a message indicating that the `bootstrap/` directory is out of scope.
6. IF the Agent is instructed to commit one or more files whose paths match `*.tfstate`, `*.tfvars`, or reside within any `.terraform/` directory, THEN THE Agent SHALL exclude those files from the commit, SHALL leave the excluded files uncommitted in the working tree, and SHALL return a message identifying each excluded path.
7. WHEN a `terraform plan` completes and its output proposes destroying or replacing one or more resources in the Persistent_Layer, the Ephemeral_Layer, or the Infra_Directory, THE Agent SHALL halt before running any further Terraform command, SHALL NOT run any command that would apply the plan, and SHALL warn the Operator with a message identifying each resource proposed for destruction or replacement.
8. WHEN a `terraform plan` completes and its output proposes no destruction or replacement of any resource, THE Agent SHALL report to the Operator that the plan contains no destructive changes.

### Requirement 10: Validation and safe-plan success criteria

**User Story:** As an infrastructure engineer, I want both layers to validate and the persistent
plan to preserve the state bucket, so that I have measurable confirmation the split is correct and
non-destructive.

#### Acceptance Criteria

1. WHEN `terraform validate` is run in the Persistent_Layer, THE Persistent_Layer SHALL report a successful validation.
2. WHEN `terraform validate` is run in the Ephemeral_Layer, THE Ephemeral_Layer SHALL report a successful validation.
3. WHEN `terraform plan` is run in the Persistent_Layer, THE plan SHALL show no destroy action against State_Bucket.
4. IF a `terraform plan` in the Persistent_Layer shows any destroy action, THEN THE Agent SHALL halt and warn the Operator before proceeding.
