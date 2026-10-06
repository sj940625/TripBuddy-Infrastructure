# ============================================================
# Amazon ElastiCache for Redis
#
# Current:
# - Legacy single-node Redis
# - App Private Subnet Group
#
# Migration target:
# - Redis Replication Group
# - Primary + Replica
# - Multi-AZ
# - Automatic Failover
# - Dedicated Cache Subnets
# - At-rest encryption
#
# The legacy Redis cluster remains in place until
# application cutover and verification are complete.
# ============================================================


# ============================================================
# 1. Legacy Redis Subnet Group
#
# Currently used by aws_elasticache_cluster.redis.
# Do not remove until migration is complete.
# ============================================================

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name = "ai-travel-redis-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "ai-travel-redis-subnet-group"
  }
}


# ============================================================
# 2. Dedicated Cache Subnet Group
#
# Used by the new Redis HA Replication Group.
# ============================================================

resource "aws_elasticache_subnet_group" "redis_dedicated_subnet_group" {
  name = "ai-travel-redis-dedicated-subnet-group"

  subnet_ids = [
    aws_subnet.cache_a.id,
    aws_subnet.cache_b.id
  ]

  tags = {
    Name = "ai-travel-redis-dedicated-subnet-group"
  }
}


# ============================================================
# 3. Redis Security Group
# ============================================================

resource "aws_security_group" "redis_sg" {
  name        = "ai-travel-redis-sg"
  description = "Allow inbound traffic from Backend only to Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis port from Backend SG"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"

    security_groups = [
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-redis-sg"
  }
}


# ============================================================
# 4. Legacy Redis
#
# Existing single-node Redis.
# Keep this resource until the new HA Redis has been
# validated and the application endpoint has been cut over.
# ============================================================

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "ai-travel-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids = [aws_security_group.redis_sg.id]

  tags = {
    Name = "ai-travel-redis-cluster"
  }
}


# ============================================================
# 5. Redis HA Replication Group
#
# Migration source snapshot:
# <redis-snapshot-id>
#
# Architecture:
# - 1 Primary
# - 1 Replica
# - Multi-AZ
# - Automatic Failover
# - Dedicated Cache Subnets
# - At-rest encryption enabled
#
# Transit encryption remains disabled during the first
# migration phase to preserve compatibility with the
# currently deployed backend configuration.
# ============================================================

resource "aws_elasticache_replication_group" "redis_ha" {
  replication_group_id = "ai-travel-redis-ha"
  description          = "AI Travel Redis HA replication group"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  parameter_group_name = "default.redis7"
  port                 = 6379

  # Primary + 1 Replica
  num_cache_clusters = 2

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name = aws_elasticache_subnet_group.redis_dedicated_subnet_group.name

  security_group_ids = [
    aws_security_group.redis_sg.id
  ]

  # Restore initial data from the existing Redis snapshot.
  snapshot_name = var.redis_ha_snapshot_name

  # Enable encryption for the new Redis.
  at_rest_encryption_enabled = true

  # Keep disabled during the first migration phase.
  # TLS migration can be handled separately after
  # backend client compatibility is confirmed.
  transit_encryption_enabled = false

  # Automated snapshots
  snapshot_retention_limit = 7
  snapshot_window          = "01:30-02:30"

  tags = {
    Name = "ai-travel-redis-ha"
  }
}


# ============================================================
# 6. Legacy Redis Outputs
#
# Keep these unchanged until application cutover.
# ============================================================

output "redis_endpoint" {
  description = "Legacy Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.redis.port
}


# ============================================================
# 7. New Redis HA Outputs
# ============================================================

output "redis_ha_primary_endpoint" {
  description = "Redis HA primary endpoint"
  value       = aws_elasticache_replication_group.redis_ha.primary_endpoint_address
}

output "redis_ha_reader_endpoint" {
  description = "Redis HA reader endpoint"
  value       = aws_elasticache_replication_group.redis_ha.reader_endpoint_address
}

output "redis_ha_port" {
  description = "Redis HA port"
  value       = aws_elasticache_replication_group.redis_ha.port
}