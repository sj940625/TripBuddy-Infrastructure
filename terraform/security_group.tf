# 1. ALB 보안 그룹 (외부 80/443 허용)
resource "aws_security_group" "alb_sg" {
  name        = "ai-travel-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-alb-sg"
  }
}

# 2. 백엔드 보안 그룹 (ALB 트래픽만 8080 허용)
resource "aws_security_group" "backend_sg" {
  name        = "ai-travel-backend-sg"
  description = "Allow traffic only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Spring Boot API Port"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-backend-sg"
  }
}