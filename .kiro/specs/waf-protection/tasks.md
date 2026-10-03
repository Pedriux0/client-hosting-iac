# Implementation Plan: WAF Protection

## Overview

This plan implements AWS WAFv2 protection for the existing internet-facing ALB (`aws_alb.main`) by adding a single new file, `persistent/waf.tf`, in the `persistent/` Terraform layer. The change is purely additive: a regional Web ACL (default `allow`) with three AWS-managed rule groups and one rate-based rule, plus an association binding the ACL to the ALB. An optional, additive output can be surfaced in `persistent/outputs.tf`.

This is Infrastructure as Code (declarative Terraform) — there is no application code and no pure function to quantify over, so property-based testing does not apply (per the design's Testing Strategy). Verification is static (`fmt`, `validate`, `plan`) plus a manual operator runtime check after apply.

> **AGENT SAFETY — READ BEFORE EXECUTING ANY TASK.** The executor runs ONLY `terraform fmt`, `terraform validate`, `terraform init`, and `terraform plan`. The executor MUST NEVER run `terraform apply`, `terraform destroy`, `terraform import`, or any `terraform state` command — those are **operator-run** (Requirement 10.1, 10.2, 10.5). The executor MUST leave everything under `bootstrap/` unmodified (Requirement 10.3). If any `terraform plan` shows a destroy or replace against a pre-existing resource, the executor MUST halt before any apply step and warn the operator with the count and resource addresses, retaining the plan output unmodified (Requirements 10.4, 11.5). Region is `us-east-1`, AWS provider `~> 5.0` (pinned 5.42.0), S3 backend with native locking.

## Tasks

- [x] 1. Scaffold `persistent/waf.tf`
  - Create the new file `persistent/waf.tf` in the persistent layer (do NOT create or modify any file under `bootstrap/`).
  - Add a brief header comment describing the file's purpose (WAFv2 Web ACL + ALB association) and noting the resources live in the persistent layer because they share the long-lived ALB's lifecycle.
  - Leave the file ready to receive the `aws_wafv2_web_acl.main` and `aws_wafv2_web_acl_association.main` resource blocks in subsequent tasks.
  - _Requirements: 1.1_

- [x] 2. Implement the Web ACL shell (default action, scope, naming/tagging, visibility)
  - [x] 2.1 Declare `aws_wafv2_web_acl.main` with scope, default action, name, and tag
    - In `persistent/waf.tf`, add resource `aws_wafv2_web_acl` named `main`.
    - Set `name = "${var.project_name}-web-acl"` and `scope = "REGIONAL"`.
    - Set `default_action { allow {} }`.
    - Add `tags = { Name = "${var.project_name}-web-acl" }` (relying on `default_tags` to add `Project`/`ManagedBy`).
    - _Requirements: 1.1, 1.2, 1.3, 9.1, 9.2_

  - [x] 2.2 Add the top-level Web ACL `visibility_config`
    - Add a top-level `visibility_config` block on `aws_wafv2_web_acl.main` with `cloudwatch_metrics_enabled = true`, `sampled_requests_enabled = true`, and `metric_name = "${var.project_name}-web-acl"`.
    - _Requirements: 8.1_

- [x] 3. Implement the three AWS managed rule groups (priority 0–2)
  - [x] 3.1 Add the Common Rule Set rule (priority 0)
    - Inside `aws_wafv2_web_acl.main`, add a `rule` block with `priority = 0` and a descriptive `name`.
    - Set `override_action { none {} }`.
    - Set `statement { managed_rule_group_statement { name = "AWSManagedRulesCommonRuleSet", vendor_name = "AWS" } }`.
    - Add a `visibility_config` with metrics + sampling enabled and `metric_name = "${var.project_name}-common-rules"`.
    - _Requirements: 2.1, 2.2, 2.3, 5.1, 5.2, 8.2_

  - [x] 3.2 Add the Known Bad Inputs rule (priority 1)
    - Inside `aws_wafv2_web_acl.main`, add a `rule` block with `priority = 1` and a descriptive `name`.
    - Set `override_action { none {} }`.
    - Set `statement { managed_rule_group_statement { name = "AWSManagedRulesKnownBadInputsRuleSet", vendor_name = "AWS" } }`.
    - Add a `visibility_config` with metrics + sampling enabled and `metric_name = "${var.project_name}-known-bad-inputs"`.
    - _Requirements: 3.1, 3.2, 3.3, 5.1, 5.3, 8.3_

  - [x] 3.3 Add the SQLi Rule Set rule (priority 2)
    - Inside `aws_wafv2_web_acl.main`, add a `rule` block with `priority = 2` and a descriptive `name`.
    - Set `override_action { none {} }`.
    - Set `statement { managed_rule_group_statement { name = "AWSManagedRulesSQLiRuleSet", vendor_name = "AWS" } }`.
    - Add a `visibility_config` with metrics + sampling enabled and `metric_name = "${var.project_name}-sqli-rules"`.
    - Confirm these are exactly the three managed rule groups — no others (Requirement 5.1).
    - _Requirements: 4.1, 4.2, 4.3, 5.1, 5.4, 8.4_

- [x] 4. Implement the rate-based rule (priority 3)
  - Inside `aws_wafv2_web_acl.main`, add a `rule` block with `priority = 3` and a descriptive `name`.
  - Set `action { block {} }` (note: non-group rules use `action`, not `override_action`).
  - Set `statement { rate_based_statement { limit = 2000, aggregate_key_type = "IP" } }` (the 300-second window is fixed by AWS and is not a configurable field).
  - Add a `visibility_config` with metrics + sampling enabled and `metric_name = "${var.project_name}-rate-limit"`.
  - Ensure exactly one rate-based rule is present.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 8.5_

- [x] 5. Implement the Web ACL to ALB association
  - In `persistent/waf.tf`, add resource `aws_wafv2_web_acl_association` named `main`.
  - Set `resource_arn = aws_alb.main.arn`.
  - Set `web_acl_arn = aws_wafv2_web_acl.main.arn`.
  - Do NOT add a `tags` argument — this resource does not support tags (Requirement 9.3 applies only where a resource supports tags).
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 6. (Optional) Surface the Web ACL ARN as an output
  - [ ]* 6.1 Add `web_acl_arn` output to `persistent/outputs.tf`
    - Add `output "web_acl_arn" { value = aws_wafv2_web_acl.main.arn }`.
    - This is additive and informational only; it has no cost or lifecycle impact. Include only if the operator wants the ARN surfaced in state outputs.
    - _Requirements: 8.1_

- [x] 7. Static verification (read-only; agent-runnable)
  - Run `terraform fmt` in `persistent/` to enforce canonical formatting (project convention).
  - Run `terraform init` in `persistent/` if the layer is not already initialized (read-only w.r.t. resources).
  - Run `terraform validate` in `persistent/` and confirm exit code 0 with ZERO errors and ZERO warnings (Requirement 11.1).
  - Run `terraform plan` in `persistent/` and confirm:
    - `aws_wafv2_web_acl.main` (with its inline managed-rule-group statements and rate-based rule) and `aws_wafv2_web_acl_association.main` are shown as **create** actions (Requirement 11.2).
    - ZERO destroy and ZERO replace actions against pre-existing resources (Requirement 11.3).
    - ZERO update-in-place actions against pre-existing resources, including `aws_alb.main` (Requirement 11.4).
  - **HALT CONDITION:** If `plan` reports any destroy or replace against a pre-existing resource, STOP before any apply step and warn the operator with the count and the resource addresses, retaining the plan output unmodified. Do NOT run `apply` or `destroy` (Requirements 10.1, 10.2, 10.4, 11.5).
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 8. Document operator-run apply and manual runtime verification
  - Add or confirm a note (in `persistent/waf.tf` header comment and/or the spec) stating that `terraform apply` is an **operator** step — the agent never applies or destroys and hands a reviewed, additive plan to the operator.
  - Document the manual runtime check the operator performs AFTER apply (this validates Requirement 6.5 / 6.6 blocking behavior, which `validate`/`plan` cannot exercise since they send no traffic):
    - Confirm the Web ACL is associated with the ALB (console or `aws wafv2 get-web-acl-for-resource`).
    - Generate a benign burst exceeding 2000 requests/5min from a single IP and confirm the rate-based rule begins returning 403 (blocked), then confirm requests succeed again after the burst subsides.
    - Inspect CloudWatch metrics and sampled requests for each rule to confirm counters move as expected.
  - _Requirements: 6.5, 6.6, 10.1, 10.2_

## Notes

- Tasks marked with `*` are optional and can be skipped (task 6.1 adds an informational output).
- Each task references specific granular requirement clauses for traceability.
- No property-based testing: this feature is declarative IaC with no pure function to test; the design's Testing Strategy specifies static validation plus a manual operator runtime check instead.
- The executor runs ONLY `fmt`, `validate`, `init`, and `plan`. `apply`/`destroy` are operator-run. If a plan shows any destroy/replace of pre-existing resources, halt and warn the operator (Requirements 10.4, 11.5).
- `bootstrap/` is never touched.
- The rate-based rule's live blocking behavior (Requirements 6.5/6.6) is verified MANUALLY by the operator with live traffic after apply — it is not something the agent verifies.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1", "3.2", "3.3", "4"] },
    { "id": 3, "tasks": ["5"] },
    { "id": 4, "tasks": ["6.1"] },
    { "id": 5, "tasks": ["7"] },
    { "id": 6, "tasks": ["8"] }
  ]
}
```
