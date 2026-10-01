# Requirements Document

## Introduction

This feature adds AWS WAFv2 protection in front of the existing Application Load Balancer (ALB) in the `persistent/` Terraform layer of the client-hosting-iac project. The ALB (`aws_alb.main`) is a regional, internet-facing Application Load Balancer in `us-east-1`, so the Web ACL must use `REGIONAL` scope and be associated directly with the ALB.

The Web ACL layers three AWS managed rule groups (common web exploits, known-bad inputs, and SQL injection) plus a rate-based rule that limits requests per client IP. CloudWatch metrics are enabled on every rule and on the Web ACL itself so that traffic and blocking behavior are observable and explainable.

This is a portfolio project intended to demonstrate cloud, DevOps, and security fundamentals for junior roles, so every requirement is written to be explainable in an interview: security first, cost near-zero, and readability throughout. All resources follow the project naming and tagging conventions and are provisioned through Terraform with the AWS provider `~> 5.0` in `us-east-1`.

## Glossary

- **WAF**: AWS WAFv2, the web application firewall service used to filter HTTP(S) traffic reaching the ALB.
- **Web_ACL**: The `aws_wafv2_web_acl` resource with `scope = REGIONAL` that contains the rules and default action and is associated with the ALB.
- **Managed_Rule_Group**: An AWS-vendor-maintained set of rules referenced inside the Web_ACL via a managed rule group statement (Common Rule Set, Known Bad Inputs Rule Set, SQL injection Rule Set).
- **Rate_Based_Rule**: A rule inside the Web_ACL using a rate-based statement that aggregates request counts by client IP address and blocks IPs that exceed the configured limit.
- **ALB**: The existing Application Load Balancer Terraform resource `aws_alb.main` in `persistent/alb.tf`, named `${var.project_name}-alb`, internal-facing set to false, regional in `us-east-1`.
- **WAF_Association**: The `aws_wafv2_web_acl_association` resource that binds the Web_ACL to the ALB by referencing the ALB ARN.
- **Persistent_Layer**: The `persistent/` Terraform working directory and its S3 state backend, where the new WAF resources are declared.
- **Agent**: The automation assistant that generates and modifies Terraform configuration and runs read-only Terraform commands.
- **Operator**: The human who reviews changes and is the only party permitted to run `terraform apply` or `terraform destroy`.
- **Project_Name**: The Terraform variable `var.project_name` used as the naming prefix; default value `client-hosting`.

## Requirements

### Requirement 1: Regional Web ACL in the Persistent Layer

**User Story:** As a security-conscious operator, I want a regional WAFv2 Web ACL declared in the persistent layer, so that HTTP(S) traffic to the ALB can be inspected and filtered.

#### Acceptance Criteria

1. THE Persistent_Layer SHALL declare a Web_ACL as an `aws_wafv2_web_acl` resource.
2. THE Web_ACL SHALL set `scope` to `REGIONAL`.
3. THE Web_ACL SHALL set the default action to `allow`.

### Requirement 2: Common Web Exploit Protection Managed Rule Group

**User Story:** As a security-conscious operator, I want the AWS Common Rule Set applied, so that common web exploits are filtered before reaching the application.

#### Acceptance Criteria

1. THE Web_ACL SHALL include a Managed_Rule_Group referencing the AWS managed rule group named `AWSManagedRulesCommonRuleSet`.
2. THE Managed_Rule_Group referencing `AWSManagedRulesCommonRuleSet` SHALL set `override_action` to `none`.
3. THE Managed_Rule_Group referencing `AWSManagedRulesCommonRuleSet` SHALL specify the vendor name `AWS`.

### Requirement 3: Known Bad Inputs Managed Rule Group

**User Story:** As a security-conscious operator, I want the AWS Known Bad Inputs Rule Set applied, so that exploitable request patterns and known-bad inputs are filtered.

#### Acceptance Criteria

1. THE Web_ACL SHALL include a Managed_Rule_Group referencing the AWS managed rule group named `AWSManagedRulesKnownBadInputsRuleSet`.
2. THE Managed_Rule_Group referencing `AWSManagedRulesKnownBadInputsRuleSet` SHALL set `override_action` to `none`.
3. THE Managed_Rule_Group referencing `AWSManagedRulesKnownBadInputsRuleSet` SHALL specify the vendor name `AWS`.

### Requirement 4: SQL Injection Managed Rule Group

**User Story:** As a security-conscious operator, I want the AWS SQL injection Rule Set applied, so that SQL injection attempts are filtered before reaching the database tier.

#### Acceptance Criteria

1. THE Web_ACL SHALL include a Managed_Rule_Group referencing the AWS managed rule group named `AWSManagedRulesSQLiRuleSet`.
2. THE Managed_Rule_Group referencing `AWSManagedRulesSQLiRuleSet` SHALL set `override_action` to `none`.
3. THE Managed_Rule_Group referencing `AWSManagedRulesSQLiRuleSet` SHALL specify the vendor name `AWS`.

### Requirement 5: Threat Coverage Through Managed Rule Groups

**User Story:** As a reviewer evaluating security coverage, I want the Web ACL to include the specific managed rule groups that address OWASP-style threat categories, so that coverage of common web exploits, known-bad inputs, and SQL injection is verifiable.

#### Acceptance Criteria

1. THE Web_ACL SHALL include exactly the three Managed_Rule_Groups `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet`, and `AWSManagedRulesSQLiRuleSet`.
2. THE Web_ACL SHALL include the Managed_Rule_Group `AWSManagedRulesCommonRuleSet` that addresses the common-web-exploit threat category.
3. THE Web_ACL SHALL include the Managed_Rule_Group `AWSManagedRulesKnownBadInputsRuleSet` that addresses the known-bad-inputs and exploitable-request-pattern threat category.
4. THE Web_ACL SHALL include the Managed_Rule_Group `AWSManagedRulesSQLiRuleSet` that addresses the SQL-injection threat category.

### Requirement 6: Rate-Based Rule per Client IP

**User Story:** As a security-conscious operator, I want a rate-based rule that limits requests per client IP, so that a single source cannot flood the application.

#### Acceptance Criteria

1. THE Web_ACL SHALL include exactly one Rate_Based_Rule that uses a rate-based statement.
2. THE Rate_Based_Rule SHALL aggregate request counts by the source IP address of each client, supporting both IPv4 and IPv6 sources.
3. THE Rate_Based_Rule SHALL define a numeric request limit between 100 and 2,000,000,000 requests, evaluated over a fixed rolling window of 300 seconds (5 minutes) per aggregated client IP.
4. THE Rate_Based_Rule SHALL set its action to `block`.
5. WHILE a client IP's request count within the 300-second evaluation window exceeds the configured request limit, THE Rate_Based_Rule SHALL block all further requests originating from that client IP.
6. WHEN a client IP's request count within the 300-second evaluation window falls to or below the configured request limit, THE Rate_Based_Rule SHALL stop blocking requests originating from that client IP.

### Requirement 7: Association Between Web ACL and ALB

**User Story:** As an operator, I want the Web ACL associated with the ALB, so that traffic to the load balancer is actually inspected by the WAF.

#### Acceptance Criteria

1. THE Persistent_Layer SHALL declare a WAF_Association as an `aws_wafv2_web_acl_association` resource.
2. THE WAF_Association SHALL reference the ARN of the ALB resource `aws_alb.main`.
3. THE WAF_Association SHALL reference the ARN of the Web_ACL.

### Requirement 8: CloudWatch Visibility on Every Rule and on the Web ACL

**User Story:** As an operator, I want CloudWatch metrics and sampled requests enabled on each rule and on the Web ACL, so that blocking behavior and traffic are observable.

#### Acceptance Criteria

1. THE Web_ACL SHALL define a `visibility_config` with `cloudwatch_metrics_enabled` set to `true`, a `metric_name`, and `sampled_requests_enabled` set to `true`.
2. THE Managed_Rule_Group referencing `AWSManagedRulesCommonRuleSet` SHALL define a `visibility_config` with `cloudwatch_metrics_enabled` set to `true`, a `metric_name`, and `sampled_requests_enabled` set to `true`.
3. THE Managed_Rule_Group referencing `AWSManagedRulesKnownBadInputsRuleSet` SHALL define a `visibility_config` with `cloudwatch_metrics_enabled` set to `true`, a `metric_name`, and `sampled_requests_enabled` set to `true`.
4. THE Managed_Rule_Group referencing `AWSManagedRulesSQLiRuleSet` SHALL define a `visibility_config` with `cloudwatch_metrics_enabled` set to `true`, a `metric_name`, and `sampled_requests_enabled` set to `true`.
5. THE Rate_Based_Rule SHALL define a `visibility_config` with `cloudwatch_metrics_enabled` set to `true`, a `metric_name`, and `sampled_requests_enabled` set to `true`.

### Requirement 9: Naming and Tagging Conventions

**User Story:** As a maintainer, I want the WAF resources to follow the project naming and tagging conventions, so that resources are consistent and identifiable.

#### Acceptance Criteria

1. THE Web_ACL SHALL set its `name` to the value `${var.project_name}-` followed by a descriptive suffix.
2. THE Web_ACL SHALL include a `Name` tag whose value uses the `${var.project_name}-` prefix.
3. WHERE a WAF resource supports tags, THE Persistent_Layer SHALL apply a `Name` tag using the `${var.project_name}-` prefix to that resource.

### Requirement 10: Agent Safety Constraints

**User Story:** As an operator, I want the agent restricted to read-only Terraform operations, so that no infrastructure is changed or destroyed without human review.

#### Acceptance Criteria

1. THE Agent SHALL execute only the Terraform commands `fmt`, `validate`, `init`, and `plan`, and SHALL execute no other Terraform command.
2. IF an operation would invoke `terraform apply`, `terraform destroy`, `terraform import`, `terraform state`, or any command that modifies Terraform state or Persistent_Layer resources, THEN THE Agent SHALL decline the operation, SHALL make no change to any resource or state file, and SHALL defer the operation to the Operator with a message indicating the command was blocked.
3. THE Agent SHALL leave all files under the `bootstrap/` directory unmodified, creating zero file additions, zero file deletions, and zero content changes within that directory.
4. WHEN a `terraform plan` run by the Agent reports a resource destruction count greater than 0 or any resource replacement, THE Agent SHALL halt further operations and SHALL warn the Operator with a message indicating the number of resources marked for destruction or replacement.
5. IF the Agent is unable to determine whether an operation is read-only, THEN THE Agent SHALL treat the operation as unsafe, SHALL decline to execute it, and SHALL defer the operation to the Operator.

### Requirement 11: Verification Success Criteria

**User Story:** As an operator, I want the change to validate cleanly and plan as additive only, so that I can trust it introduces the WAF without disturbing existing resources.

#### Acceptance Criteria

1. WHEN `terraform validate` runs in the Persistent_Layer, THE Persistent_Layer SHALL complete with an exit code of 0 and report zero validation errors and zero validation warnings.
2. WHEN `terraform plan` runs in the Persistent_Layer, THE Persistent_Layer SHALL show the Web_ACL, all associated Managed_Rule_Group statements, the Rate_Based_Rule, and the WAF_Association to the ALB as create actions.
3. WHEN `terraform plan` runs in the Persistent_Layer, THE Persistent_Layer SHALL report zero destroy actions and zero replace actions against resources existing prior to the WAF change.
4. WHEN `terraform plan` runs in the Persistent_Layer, THE Persistent_Layer SHALL report zero update-in-place actions against resources existing prior to the WAF change, including the ALB resource `aws_alb.main`.
5. IF `terraform plan` reports one or more destroy or replace actions against resources existing prior to the WAF change, THEN THE Agent SHALL halt execution before any apply step and present the Operator with the count and resource addresses of the affected resources, retaining the generated plan output without modification.
