# ============================================================
# EKS Pod Identity
#
# Infrastructure ownership:
# - EKS Pod Identity Agent
# - IAM Roles / IAM Policies
# - Pod Identity Associations
#
# Kubernetes ServiceAccounts / Deployments are managed
# by the DevOps Kubernetes manifests.
# ============================================================


# ============================================================
# 1. EKS Pod Identity Agent
# ============================================================
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.10-eksbuild.3"
}


# ============================================================
# 2. Pod Identity Trust Policy
# ============================================================
data "aws_iam_policy_document" "pod_identity_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}


# ============================================================
# 3. API IAM Role
#
# travel-api-sa
#   -> ai-travel-api-sqs-role
# ============================================================
resource "aws_iam_role" "travel_api_sqs" {
  name                 = "ai-travel-api-sqs-role"
  path                 = "/"
  max_session_duration = 3600

  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json
}


# API can only send messages to the AI Jobs queue.
resource "aws_iam_role_policy" "travel_api_sqs_send" {
  name = "ai-travel-api-sqs-send-policy"
  role = aws_iam_role.travel_api_sqs.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "SendMessageToTravelAIJobs"
        Effect = "Allow"

        Action = [
          "sqs:SendMessage"
        ]

        Resource = aws_sqs_queue.ai_jobs.arn
      }
    ]
  })
}


# ============================================================
# 4. Worker IAM Role
#
# travel-worker-sa
#   -> ai-travel-worker-role
# ============================================================
resource "aws_iam_role" "travel_worker" {
  name                 = "ai-travel-worker-role"
  path                 = "/"
  max_session_duration = 3600

  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json
}


# ============================================================
# 5. Worker SQS Policy
# ============================================================
resource "aws_iam_role_policy" "travel_worker_sqs" {
  name = "ai-travel-worker-sqs-policy"
  role = aws_iam_role.travel_worker.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ConsumeTravelAIJobs"
        Effect = "Allow"

        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes"
        ]

        Resource = aws_sqs_queue.ai_jobs.arn
      }
    ]
  })
}


# ============================================================
# 6. Worker Bedrock Policy
#
# Nova Lite through APAC Inference Profile only.
# Streaming permission is intentionally not granted.
# ============================================================
resource "aws_iam_role_policy" "travel_worker_bedrock" {
  name = "ai-travel-worker-bedrock-policy"
  role = aws_iam_role.travel_worker.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "InvokeAPACNovaLiteInferenceProfile"
        Effect = "Allow"

        Action = [
          "bedrock:InvokeModel"
        ]

        Resource = [
          "arn:aws:bedrock:ap-northeast-2:${var.aws_account_id}:inference-profile/apac.amazon.nova-lite-v1:0"
        ]
      },
      {
        Sid    = "InvokeNovaLiteThroughInferenceProfile"
        Effect = "Allow"

        Action = [
          "bedrock:InvokeModel"
        ]

        Resource = [
          "arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.nova-lite-v1:0",
          "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.nova-lite-v1:0",
          "arn:aws:bedrock:ap-south-1::foundation-model/amazon.nova-lite-v1:0",
          "arn:aws:bedrock:ap-northeast-2::foundation-model/amazon.nova-lite-v1:0",
          "arn:aws:bedrock:ap-southeast-1::foundation-model/amazon.nova-lite-v1:0",
          "arn:aws:bedrock:ap-northeast-3::foundation-model/amazon.nova-lite-v1:0"
        ]

        Condition = {
          StringEquals = {
            "bedrock:InferenceProfileArn" = "arn:aws:bedrock:ap-northeast-2:${var.aws_account_id}:inference-profile/apac.amazon.nova-lite-v1:0"
          }
        }
      }
    ]
  })
}


# ============================================================
# 7. API Pod Identity Association
#
# Kubernetes ServiceAccount itself remains under DevOps.
# ============================================================
resource "aws_eks_pod_identity_association" "travel_api" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "travel"
  service_account = "travel-api-sa"
  role_arn        = aws_iam_role.travel_api_sqs.arn

}


# ============================================================
# 8. Worker Pod Identity Association
# ============================================================
resource "aws_eks_pod_identity_association" "travel_worker" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "travel"
  service_account = "travel-worker-sa"
  role_arn        = aws_iam_role.travel_worker.arn

}