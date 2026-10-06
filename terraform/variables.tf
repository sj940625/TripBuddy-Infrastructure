# ==========================================
# RDS Variables
# ==========================================

variable "rds_username" {
  description = "RDS MariaDB master username"
  type        = string
  default     = "tripbuddy_admin"
}

variable "rds_password" {
  description = "RDS MariaDB master password"
  type        = string
  sensitive   = true
}
# ==========================================
# Bedrock VPC Endpoint Enable / Disable
# 개발 환경에서는 비용 절감을 위해 비활성화
# ==========================================
variable "enable_bedrock_vpce" {
  description = "Whether to create the Bedrock Runtime VPC Interface Endpoint"
  type        = bool
  default     = false
}

# ==========================================
# Public portfolio / environment-specific values
# ==========================================
variable "aws_account_id" {
  description = "12-digit AWS account ID used by account-scoped ARNs"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "frontend_bucket_name" {
  description = "Globally unique S3 bucket name for frontend assets"
  type        = string
}

variable "github_backend_repository" {
  description = "GitHub repository allowed to assume the backend ECR role, e.g. my-org/backend"
  type        = string
}

variable "eks_admin_user_arns" {
  description = "IAM principal ARNs granted EKS cluster admin access"
  type        = list(string)
  default     = []
}

variable "public_alb_domain_name" {
  description = "Legacy/public ALB DNS name retained during API origin migration"
  type        = string
}

variable "internal_alb_domain_name" {
  description = "Internal ALB DNS name used by CloudFront VPC Origin"
  type        = string
}

variable "internal_alb_arn" {
  description = "Internal ALB ARN used by CloudFront VPC Origin"
  type        = string
}

variable "redis_ha_snapshot_name" {
  description = "Optional Redis snapshot used to seed the HA replication group"
  type        = string
  default     = null
}

variable "existing_rds_identifier" {
  description = "RDS identifier used by the SSM/Secrets integration data source"
  type        = string
  default     = "ai-travel-mariadb"
}
