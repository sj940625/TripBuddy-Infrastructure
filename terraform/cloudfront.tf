# ==========================================
# 1. CloudFront Origin Access Control (OAC) 생성
# ==========================================
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "ai-travel-frontend-oac"
  description                       = "OAC for AI Travel Frontend S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ==========================================
# 2. CloudFront Distribution 생성
# ==========================================
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "AI Travel Frontend CloudFront Distribution"
  # AWS WAFv2
  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  # ==========================================
  # Frontend S3 Origin
  # ==========================================
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  # ==========================================
  # Backend API Public ALB Origin
  #
  # 현재 /api/* 실제 트래픽이 사용 중
  # Internal ALB 전환 완료 후 제거 예정
  # ==========================================
  origin {
    domain_name = var.public_alb_domain_name
    origin_id   = "travel-api-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"

      # 현재 실제 CloudFront 설정과 동일하게 유지
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  # ==========================================
  # Backend API Internal ALB VPC Origin
  #
  # 신규 VPC Origin
  # 현재는 Origin에 등록만 하고
  # /api/* 트래픽은 아직 Public ALB 사용
  # ==========================================
  origin {
    domain_name = var.internal_alb_domain_name

    # CloudFront VPC Origin 실제 ID 사용
    # 현재 값: vo_KUiFEEbSeDxBwUeeL2m01M
    origin_id = aws_cloudfront_vpc_origin.travel_api.id

    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.travel_api.id
    }
  }

  # ==========================================
  # Frontend 기본 캐시 동작
  # ==========================================
  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    # AWS Managed Policy: CachingOptimized
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    compress = true
  }

  # ==========================================
  # Backend API Routing
  #
  # 중요:
  # 아직 기존 Public ALB 사용
  # 다음 단계에서 VPC Origin으로 전환 예정
  # ==========================================
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = aws_cloudfront_vpc_origin.travel_api.id

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    # AWS Managed Policy: CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AWS Managed Policy: AllViewerExceptHostHeader
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

    compress = true
  }

  # ==========================================
  # CloudFront Edge Location 범위
  # ==========================================
  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ==========================================
  # 현재 CloudFront 기본 인증서 사용
  # 추후 Route53 + ACM 적용 시 변경
  # ==========================================
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "ai-travel-frontend-cf"
  }
}

# ==========================================
# 3. S3 버킷 정책
# CloudFront OAC 접근만 허용
# ==========================================
data "aws_iam_policy_document" "s3_oac_policy" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.s3_oac_policy.json
}

# ==========================================
# 4. 프론트엔드 접속 주소 출력
# ==========================================
output "cloudfront_domain_name" {
  description = "프론트엔드 웹 서비스 접속 URL"
  value       = "https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"
}