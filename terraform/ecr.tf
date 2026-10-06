# ==========================================
# 1. 백엔드 Spring Boot용 Amazon ECR 리포지토리
# ==========================================
resource "aws_ecr_repository" "backend" {
  name                 = "ai-travel-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # 테라폼 정리 시 이미지가 있어도 삭제 가능

  # 이미지 푸시 시 보안 취약점 자동 스캔
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "ai-travel-backend-ecr"
  }
}

# ==========================================
# 2. 이미지 보관 수명주기 정책 (스토리지 비용 최적화)
# ==========================================
resource "aws_ecr_lifecycle_policy" "backend_lifecycle" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ==========================================
# 3. 도커 빌드/푸시 및 CI/CD용 URL 출력
# ==========================================
output "ecr_repository_url" {
  description = "ECR 레지스트리 저장소 주소"
  value       = aws_ecr_repository.backend.repository_url
}