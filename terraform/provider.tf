terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==========================================
# Main AWS Provider
# Seoul Region
# ==========================================
provider "aws" {
  region              = "ap-northeast-2"
  allowed_account_ids = [var.aws_account_id]
}

# ==========================================
# CloudFront / WAF Provider
# CloudFront Scope WAF는 us-east-1에서 관리
# ==========================================
provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.aws_account_id]
}