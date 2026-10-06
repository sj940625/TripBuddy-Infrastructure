# ==========================================
# AI Travel SQS / DLQ
#
# API    -> Main Queue : SendMessage
# Worker -> Main Queue : Receive/Delete
# Failed message      -> DLQ
# ==========================================


# ==========================================
# 1. AI Jobs Dead Letter Queue
# ==========================================
resource "aws_sqs_queue" "ai_jobs_dlq" {
  name = "ai-travel-ai-jobs-dlq"

  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600
  delay_seconds              = 0
  receive_wait_time_seconds  = 0

  sqs_managed_sse_enabled = true

  # 현재 AWS Queue는 MaximumMessageSize = 1 MiB.
  # AWS Provider 5.x가 아직 256 KiB까지만 validation하므로
  # Provider 업그레이드 전까지 실제 AWS 값을 유지한다.
  lifecycle {
    ignore_changes = [
      max_message_size
    ]
  }
}


# ==========================================
# 2. AI Jobs Main Queue
# ==========================================
resource "aws_sqs_queue" "ai_jobs" {
  name = "ai-travel-ai-jobs"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
  delay_seconds              = 0

  # Long Polling
  receive_wait_time_seconds = 20

  sqs_managed_sse_enabled = true

  # 3회 처리 실패 후 DLQ 이동
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ai_jobs_dlq.arn
    maxReceiveCount     = 3
  })

  # 실제 AWS Queue는 1 MiB.
  # AWS Provider 5.x 제한 때문에 현재 값은 AWS 측 설정을 유지.
  lifecycle {
    ignore_changes = [
      max_message_size
    ]
  }
}