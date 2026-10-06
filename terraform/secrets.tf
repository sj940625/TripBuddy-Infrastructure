# ============================================================
# AWS Secrets Manager / SSM Parameter Store
#
# Secret values themselves are NOT managed by Terraform.
# Terraform manages only:
# - Secrets Manager secret container
# - Non-sensitive configuration parameters
#
# Passwords, API keys, JWT secrets, etc. must NOT be written
# directly in Terraform code.
# ============================================================


# ============================================================
# Existing RDS Information
#
# Read the currently running RDS instance information.
#
# Using a data source here prevents the SSM parameter from
# depending directly on the Terraform-managed RDS resource.
# This is important because the RDS backup retention change
# is currently waiting for the maintenance window.
# ============================================================

data "aws_db_instance" "mariadb_current" {
  db_instance_identifier = var.existing_rds_identifier
}


# ============================================================
# Backend Secrets Manager
#
# This creates ONLY the Secrets Manager container.
#
# Actual values such as:
# - SPRING_DATASOURCE_USERNAME
# - SPRING_DATASOURCE_PASSWORD
# - JWT_SECRET
# - API Keys
#
# will be inserted separately and will not be stored
# in Terraform configuration.
# ============================================================

resource "aws_secretsmanager_secret" "backend" {
  name        = "ai-travel/backend"
  description = "Secrets for AI Travel backend application"

  tags = {
    Name = "ai-travel-backend-secrets"
  }
}


# ============================================================
# Backend Datasource URL
#
# Database hostname / port / database name are not treated
# as secret values.
#
# DB username and password will remain in Secrets Manager.
# ============================================================

resource "aws_ssm_parameter" "backend_datasource_url" {
  name        = "/ai-travel/backend/spring-datasource-url"
  description = "Spring datasource URL for AI Travel backend"
  type        = "String"

  value = "jdbc:mariadb://${data.aws_db_instance.mariadb_current.address}:${data.aws_db_instance.mariadb_current.port}/aitravel"

  tags = {
    Name = "ai-travel-backend-datasource-url"
  }
}