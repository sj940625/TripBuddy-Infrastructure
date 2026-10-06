resource "aws_s3_bucket" "frontend" {
  bucket        = var.frontend_bucket_name
  force_destroy = true

  tags = {
    Name = "ai-travel-frontend-bucket"
  }
}

# 프라이빗 유지 (퍼블릭 접근 차단)
resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}