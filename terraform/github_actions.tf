# ==========================================
# GitHub Actions OIDC
#
# 기존 AWS 계정에 이미 존재하는
# token.actions.githubusercontent.com
# OIDC Provider를 조회해서 재사용
#
# Provider 자체는 Terraform에서 새로 생성하지 않음
# ==========================================
data "aws_iam_openid_connect_provider" "github_actions" {
  arn = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
}


# ==========================================
# GitHub Actions Backend Trust Policy
#
# 지정한 Backend GitHub Repository에서만
# GitHub OIDC를 통해 AssumeRole 허용
# ==========================================
data "aws_iam_policy_document" "github_actions_backend_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_backend_repository}:*"
      ]
    }
  }
}


# ==========================================
# GitHub Actions Backend IAM Role
#
# 기존 AWS Role을 Terraform으로 Import할 예정
# ==========================================
resource "aws_iam_role" "github_actions_backend_ecr" {
  name = "GitHubActions-Backend-ECR-Role"

  assume_role_policy = data.aws_iam_policy_document.github_actions_backend_assume_role.json

  description = "GitHub Actions OIDC role for AI Travel backend ECR"

  tags = {
    Name = "GitHubActions-Backend-ECR-Role"
  }
}


# ==========================================
# GitHub Actions Backend ECR Policy
#
# 현재 AWS에 존재하는 Inline Policy와
# 동일한 권한을 Terraform으로 관리
# ==========================================
data "aws_iam_policy_document" "github_actions_backend_ecr" {

  # ECR Login
  statement {
    sid    = "ECRLogin"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = [
      "*"
    ]
  }

  # Backend Image Push + Scan
  statement {
    sid    = "ECRPushAndScan"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:StartImageScan",
      "ecr:DescribeImageScanFindings",
      "ecr:DescribeImages"
    ]

    # 현재 AWS Inline Policy와 동일하게 유지
    resources = [
      aws_ecr_repository.backend.arn
    ]
  }
}


# ==========================================
# GitHub Actions Backend Inline Policy
#
# 기존 AWS Inline Policy를 Import할 예정
# ==========================================
resource "aws_iam_role_policy" "github_actions_backend_ecr" {
  name = "GitHubActions-Backend-ECR-Policy"
  role = aws_iam_role.github_actions_backend_ecr.name

  policy = data.aws_iam_policy_document.github_actions_backend_ecr.json
}