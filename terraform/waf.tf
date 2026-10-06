# ==========================================
# AWS WAFv2
# CloudFront Web ACL
#
# 1차 적용:
# AWS Managed Rules를 COUNT 모드로 적용
# 실제 요청 차단 없이 탐지/샘플링만 수행
# ==========================================

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name        = "ai-travel-cloudfront-waf"
  description = "AWS WAF for AI Travel CloudFront Distribution"
  scope       = "CLOUDFRONT"

  # 기본적으로 요청 허용
  default_action {
    allow {}
  }

  # ==========================================
  # Rule 1
  # AWS Common Rule Set
  #
  # 일반적인 웹 공격 패턴 탐지
  # 현재는 COUNT 모드
  # ==========================================
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # ==========================================
  # Rule 2
  # Known Bad Inputs
  #
  # 알려진 악성 요청 패턴 탐지
  # 현재는 COUNT 모드
  # ==========================================
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # ==========================================
  # Rule 3
  # Amazon IP Reputation
  #
  # AWS가 관리하는 악성 IP 평판 목록
  # 현재는 COUNT 모드
  # ==========================================
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 30

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # ==========================================
  # Web ACL Monitoring
  # ==========================================
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ai-travel-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "ai-travel-cloudfront-waf"
  }
}