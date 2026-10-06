# ==========================================
# 1. 기존 RDS Subnet Group
#
# 현재 MariaDB가 사용 중인 App Private Subnet A/B
# Dedicated DB Subnet 마이그레이션 완료 전까지 유지
# ==========================================
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "ai-travel-rds-subnet-group"
  description = "RDS DB subnet group in private subnets"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "ai-travel-rds-subnet-group"
  }
}


# ==========================================
# 2. RDS Dedicated DB Subnet Group
#
# DB 전용 Private Subnet A/B
# - 10.0.30.0/24 : ap-northeast-2a
# - 10.0.40.0/24 : ap-northeast-2c
#
# 현재는 생성만 완료된 상태이며,
# MariaDB는 아직 기존 Subnet Group 사용
# ==========================================
resource "aws_db_subnet_group" "rds_dedicated_subnet_group" {
  name        = "ai-travel-rds-dedicated-subnet-group"
  description = "Dedicated private DB subnets for AI Travel MariaDB"

  subnet_ids = [
    aws_subnet.db_a.id,
    aws_subnet.db_b.id
  ]

  tags = {
    Name = "ai-travel-rds-dedicated-subnet-group"
  }
}


# ==========================================
# 3. RDS 전용 Security Group
#
# EKS Worker / Pod -> MariaDB TCP 3306 허용
# ==========================================
resource "aws_security_group" "rds_sg" {
  name = "ai-travel-rds-sg"

  # 기존 Security Group replacement 방지를 위해
  # 기존 AWS description 유지
  description = "Allow inbound traffic from Backend only"

  vpc_id = aws_vpc.main.id

  # ------------------------------------------
  # EKS Workload -> MariaDB
  # ------------------------------------------
  ingress {
    description = "MariaDB from EKS workloads"

    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = [
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]
  }

  # ------------------------------------------
  # Outbound
  # ------------------------------------------
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-rds-sg"
  }
}


# ==========================================
# 4. Amazon RDS for MariaDB
#
# Multi-AZ
#
# 현재:
# ai-travel-rds-subnet-group 사용
#
# 향후:
# Dedicated DB Subnet으로 별도 마이그레이션 예정
# ==========================================
resource "aws_db_instance" "mariadb" {
  identifier = "ai-travel-mariadb"

  # ------------------------------------------
  # Database Engine
  # ------------------------------------------
  engine         = "mariadb"
  engine_version = "10.11"

  # ------------------------------------------
  # Instance / Storage
  # ------------------------------------------
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"

  # ------------------------------------------
  # Database
  # ------------------------------------------
  db_name  = "aitravel"
  username = var.rds_username

  # 실제 비밀번호는 terraform.tfvars에서 관리
  password = var.rds_password

  # ------------------------------------------
  # High Availability
  # ------------------------------------------
  multi_az = true

  # ------------------------------------------
  # Network
  #
  # 현재 운영 중인 기존 Subnet Group 유지
  # ------------------------------------------
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  vpc_security_group_ids = [
    aws_security_group.rds_sg.id
  ]

  publicly_accessible = false

  # ------------------------------------------
  # Backup / Recovery
  # ------------------------------------------

  # Automated Backup + PITR
  # 최근 7일 이내 특정 시점으로 복구 가능
  backup_retention_period = 7

  # 현재 AWS에 설정된 Backup Window 유지
  backup_window = "15:30-16:00"

  # RDS 태그를 Snapshot에도 복사
  copy_tags_to_snapshot = true


  # ------------------------------------------
  # 현재 개발 단계 설정
  #
  # KMS Encryption / Deletion Protection은
  # 별도 단계에서 적용 검토
  # ------------------------------------------
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "ai-travel-mariadb-instance"
  }
}


# ==========================================
# 5. Outputs
# Backend 전달용 RDS 연결 정보
# ==========================================
output "rds_endpoint" {
  description = "MariaDB endpoint address"
  value       = aws_db_instance.mariadb.address
}

output "rds_port" {
  description = "MariaDB port"
  value       = aws_db_instance.mariadb.port
}