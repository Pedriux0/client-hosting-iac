# waf.tf — AWS WAFv2 protection for the internet-facing ALB (aws_alb.main)
#
# Purpose:
#   Declares a regional WAFv2 Web ACL (aws_wafv2_web_acl.main) and the
#   association that binds it to the existing ALB (aws_wafv2_web_acl_association.main).
#   The Web ACL layers three AWS-managed rule groups (common web exploits,
#   known-bad inputs, SQL injection) plus a per-client-IP rate-based rule,
#   with CloudWatch metrics and sampled requests enabled for observability.
#
# Why this lives in the persistent layer:
#   These WAF resources protect the long-lived ALB and must share its
#   lifecycle. They belong alongside the ALB in the persistent/ layer so they
#   are not torn down with the ephemeral layer.
#
# Operational note — apply/destroy are OPERATOR-run:
#   `terraform apply` and `terraform destroy` are operator steps. The agent
#   only runs read-only Terraform commands (fmt, validate, init, plan) and
#   never applies, destroys, imports, or mutates state. The agent hands a
#   reviewed, strictly additive plan (create-only for the Web ACL and the
#   association; zero destroy/replace/update-in-place against pre-existing
#   resources such as aws_alb.main) to the operator, who performs the apply.
#
# Manual runtime verification — OPERATOR performs these AFTER apply:
#   The rate-based rule's live blocking behavior cannot be exercised by
#   `validate`/`plan` because those commands send no traffic. After apply the
#   operator confirms runtime behavior with these steps:
#     1. Confirm the Web ACL is associated with the ALB — via the console or
#        `aws wafv2 get-web-acl-for-resource --resource-arn <alb-arn> --region us-east-1`.
#     2. Generate a benign burst exceeding 2000 requests / 5 min from a single
#        source IP and confirm the rate-based rule begins returning HTTP 403
#        (requests blocked); then confirm requests succeed again once the burst
#        subsides and the trailing-window count drops back to/below the limit.
#     3. Inspect CloudWatch metrics and sampled requests for each rule
#        (common-rules, known-bad-inputs, sqli-rules, rate-limit, and the
#        web-acl aggregate) to confirm the counters move as expected.
#
# Resource blocks follow below.
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  tags = { Name = "${var.project_name}-web-acl" }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${var.project_name}-web-acl"
  }

  # AWS managed Common Rule Set — protects against a broad range of common
  # web exploits (OWASP Top 10 style). Managed rule groups use override_action.
  rule {
    name     = "${var.project_name}-common-rules"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${var.project_name}-common-rules"
    }
  }

  # AWS managed Known Bad Inputs rule set — blocks request patterns known to
  # be invalid and associated with exploitation or discovery of vulnerabilities.
  # Managed rule groups use override_action.
  rule {
    name     = "${var.project_name}-known-bad-inputs"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${var.project_name}-known-bad-inputs"
    }
  }

  # AWS managed SQL injection (SQLi) rule set — blocks request patterns
  # associated with SQL injection attacks. Managed rule groups use override_action.
  rule {
    name     = "${var.project_name}-sqli-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${var.project_name}-sqli-rules"
    }
  }

  # Rate-based rule — flood control per client IP. WAF counts requests per
  # source IP (IPv4 or IPv6) over a fixed 300-second (5-minute) sliding window
  # and blocks an IP once it exceeds the limit; blocking stops automatically
  # when the trailing-window count drops back to or below the limit. Non-group
  # rules use `action` (not override_action). The 300-second window is fixed by
  # AWS and is not a configurable field, so only limit + aggregate_key_type are set.
  rule {
    name     = "${var.project_name}-rate-limit"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${var.project_name}-rate-limit"
    }
  }
}

# Association — binds the Web ACL above to the existing internet-facing ALB
# (aws_alb.main) so that traffic reaching the load balancer is inspected by WAF.
# This is a separate resource (it does not modify aws_alb.main in place), so the
# plan stays additive. The association resource does not support tags.
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_alb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
