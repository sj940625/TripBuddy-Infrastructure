# ==========================================
# CloudFront Origin-Facing Managed Prefix List
# ==========================================
data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# ==========================================
# Internal ALB Security Group
# CloudFront -> Internal ALB
# ==========================================
resource "aws_security_group" "internal_alb_sg" {
  name        = "ai-travel-internal-alb-sg"
  description = "Allow HTTP traffic from CloudFront to Internal ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from CloudFront origin-facing servers"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    prefix_list_ids = [
      data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
    ]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-internal-alb-sg"
  }
}