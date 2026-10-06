# =======================================================
# 1. EKS 클러스터용 IAM OIDC Provider 등록
# =======================================================
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "ai-travel-eks-oidc-provider"
  }
}

# =======================================================
# 2. AWS Load Balancer Controller용 IAM 정책 생성 (이름 충돌 방지)
# =======================================================
resource "aws_iam_policy" "alb_controller" {
  name        = "ai-travel-alb-controller-policy"
  description = "IAM Policy for AWS Load Balancer Controller on EKS"
  policy      = file("${path.module}/iam_policy_alb.json")
}

# =======================================================
# 3. AWS Load Balancer Controller용 IAM 역할 (IRSA)
# =======================================================
data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json

  tags = {
    Name = "ai-travel-alb-controller-role"
  }
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}

# =======================================================
# 4. DevOps(soo) 전달용 Role ARN 출력
# =======================================================
output "alb_controller_role_arn" {
  description = "AWS Load Balancer Controller에 연결할 IAM Role ARN"
  value       = aws_iam_role.alb_controller.arn
}