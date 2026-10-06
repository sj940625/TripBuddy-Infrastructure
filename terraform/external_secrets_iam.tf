# ============================================================
# External Secrets Operator IAM
#
# Infra responsibility:
# - IAM Role
# - Least privilege AWS permissions
#
# DevOps responsibility:
# - Install External Secrets Operator
# - Create Kubernetes ServiceAccount
# - SecretStore / ExternalSecret manifests
#
# Pod Identity association will be added after the
# ServiceAccount name is confirmed by DevOps.
# ============================================================


# ============================================================
# External Secrets IAM Role
# ============================================================

resource "aws_iam_role" "external_secrets" {
  name                 = "ai-travel-external-secrets-role"
  path                 = "/"
  max_session_duration = 3600

  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json

  tags = {
    Name = "ai-travel-external-secrets-role"
  }
}


# ============================================================
# External Secrets Permissions
#
# Secrets Manager:
#   ai-travel/backend
#
# SSM Parameter Store:
#   /ai-travel/backend/spring-datasource-url
# ============================================================

resource "aws_iam_role_policy" "external_secrets_read" {
  name = "ai-travel-external-secrets-read-policy"
  role = aws_iam_role.external_secrets.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadBackendSecrets"
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]

        Resource = aws_secretsmanager_secret.backend.arn
      },
      {
        Sid    = "ReadBackendParameters"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]

        Resource = aws_ssm_parameter.backend_datasource_url.arn
      }
    ]
  })
}

# ============================================================
# EKS Pod Identity Association
#
# External Secrets Operator must use:
#
# Namespace      : external-secrets
# ServiceAccount : external-secrets
#
# DevOps must install the operator using these exact names.
# ============================================================

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = "ai-travel-eks-cluster"
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}