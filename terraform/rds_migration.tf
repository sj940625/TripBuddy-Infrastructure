# ============================================================
# AI Travel RDS Migration
#
# Purpose:
# Restore a new encrypted MariaDB instance from
# an encrypted RDS snapshot.
#
# Target architecture:
# - Dedicated DB Private Subnets
# - Multi-AZ
# - KMS Storage Encryption
# - Automated Backup / PITR
# - Deletion Protection
#
# IMPORTANT:
# This resource does not modify the existing RDS instance.
#
# Default:
# enable_new_rds = false
# ============================================================


# ============================================================
# 1. New Encrypted RDS Instance
# ============================================================

resource "aws_db_instance" "mariadb_encrypted" {

  # ----------------------------------------------------------
  # Creation Control
  # ----------------------------------------------------------

  count = var.enable_new_rds ? 1 : 0


  # ----------------------------------------------------------
  # Instance Identifier
  #
  # Different from the existing production RDS.
  # ----------------------------------------------------------

  identifier = "ai-travel-mariadb-encrypted"


  # ----------------------------------------------------------
  # Restore From Encrypted Snapshot
  #
  # The final snapshot identifier will be specified
  # when the actual migration is scheduled.
  # ----------------------------------------------------------

  snapshot_identifier = var.new_rds_snapshot_identifier


  # ----------------------------------------------------------
  # Instance / Storage
  # ----------------------------------------------------------

  instance_class = "db.t3.micro"

  storage_type = "gp3"

  max_allocated_storage = 100


  # ----------------------------------------------------------
  # High Availability
  # ----------------------------------------------------------

  multi_az = true


  # ----------------------------------------------------------
  # Dedicated DB Network
  #
  # 10.0.30.0/24 : ap-northeast-2a
  # 10.0.40.0/24 : ap-northeast-2c
  # ----------------------------------------------------------

  db_subnet_group_name = aws_db_subnet_group.rds_dedicated_subnet_group.name

  vpc_security_group_ids = [
    aws_security_group.rds_sg.id
  ]

  publicly_accessible = false


  # ----------------------------------------------------------
  # Storage Encryption
  #
  # The source snapshot must already be encrypted.
  # The restored instance inherits the snapshot encryption.
  # ----------------------------------------------------------

  storage_encrypted = true


  # ----------------------------------------------------------
  # Automated Backup / PITR
  # ----------------------------------------------------------

  backup_retention_period = 7

  backup_window = "15:30-16:00"

  copy_tags_to_snapshot = true


  # ----------------------------------------------------------
  # Deletion Protection / Recovery
  # ----------------------------------------------------------

  deletion_protection = true

  skip_final_snapshot = false

  final_snapshot_identifier = "ai-travel-mariadb-encrypted-final"


  # ----------------------------------------------------------
  # Lifecycle Safety
  #
  # Prevent accidental deletion or replacement of
  # the restored database through Terraform.
  # ----------------------------------------------------------

  lifecycle {

    prevent_destroy = true

    precondition {
      condition     = trimspace(var.new_rds_snapshot_identifier) != ""
      error_message = "Specify an encrypted RDS snapshot before enabling new RDS creation."
    }

  }


  # ----------------------------------------------------------
  # Tags
  # ----------------------------------------------------------

  tags = {
    Name    = "ai-travel-mariadb-encrypted"
    Project = "ai-travel"
    Purpose = "rds-migration"
  }
}


# ============================================================
# 2. New RDS Endpoint Output
#
# The existing rds_endpoint output remains unchanged.
# ============================================================

output "rds_encrypted_endpoint" {

  description = "Endpoint of the new encrypted MariaDB instance"

  value = try(
    aws_db_instance.mariadb_encrypted[0].address,
    null
  )

}


# ============================================================
# 3. New RDS Port Output
# ============================================================

output "rds_encrypted_port" {

  description = "Port of the new encrypted MariaDB instance"

  value = try(
    aws_db_instance.mariadb_encrypted[0].port,
    null
  )

}


# ============================================================
# 4. New RDS Identifier Output
# ============================================================

output "rds_encrypted_identifier" {

  description = "Identifier of the new encrypted MariaDB instance"

  value = try(
    aws_db_instance.mariadb_encrypted[0].identifier,
    null
  )

}