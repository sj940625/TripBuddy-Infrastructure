# ============================================================
# RDS Migration Variables
#
# Controls creation of the new encrypted RDS instance.
#
# Default:
# - No new RDS instance is created.
# - Existing production RDS remains unchanged.
# ============================================================


# ------------------------------------------------------------
# Enable / Disable New RDS Creation
# ------------------------------------------------------------

variable "enable_new_rds" {
  description = "Whether to create the new encrypted RDS instance for migration"

  type    = bool
  default = false
}


# ------------------------------------------------------------
# Encrypted Snapshot Identifier
#
# Specify the final encrypted snapshot when the migration
# date is confirmed.
#
# Do not use an old snapshot for the final production cutover.
# ------------------------------------------------------------

variable "new_rds_snapshot_identifier" {
  description = "Encrypted RDS snapshot to restore for migration"

  type    = string
  default = ""
}