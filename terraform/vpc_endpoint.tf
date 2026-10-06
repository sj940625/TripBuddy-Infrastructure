# ==========================================
# 1. Bedrock VPC Endpoint Security Group
# ==========================================
resource "aws_security_group" "bedrock_vpce_sg" {
  name        = "ai-travel-bedrock-vpce-sg"
  description = "Allow HTTPS inbound traffic from Backend to Bedrock endpoint"
  vpc_id      = aws_vpc.main.id

  # Backend SG -> Bedrock VPC Endpoint
  ingress {
    description     = "HTTPS from Backend SG"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  # EKS Cluster SG -> Bedrock VPC Endpoint
  ingress {
    description     = "HTTPS from EKS cluster security group"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-bedrock-vpce-sg"
  }
}

# ==========================================
# 2. Bedrock Runtime VPC Interface Endpoint
# ==========================================
resource "aws_vpc_endpoint" "bedrock_runtime" {
  count = var.enable_bedrock_vpce ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.bedrock_vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "ai-travel-bedrock-runtime-vpce"
  }
}