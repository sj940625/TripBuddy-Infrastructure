# ============================================================
# Cluster Autoscaler IAM
#
# The original team-specific IAM users/group were intentionally
# excluded from the public portfolio copy. EKS access is provided
# through var.eks_admin_user_arns in eks_access.tf.
# ============================================================

# Cluster Autoscaler 권한 정책
resource "aws_iam_policy" "cluster_autoscaler" {
  name = "ai-travel-cluster-autoscaler-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# 주의: 아래 'aws_iam_role.EKS_NODE_ROLE_NAME.name' 부분은 
# 기존 iam.tf에 있는 EKS 노드 그룹 역할(Role) 이름으로 변경해야 합니다.
resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.eks_node_role.name # <--- 이 부분에 적용 완료
}
# 오토스케일러용 IAM 역할 생성 및 OIDC 신뢰 관계 설정
resource "aws_iam_role" "cluster_autoscaler_role" {
  name = "ai-travel-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity",
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      },
      Condition = {
        "StringEquals" = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler-aws-cluster-autoscaler"
        }
      }
    }]
  })
}

# 역할에 권한(Policy) 연결
resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach_oidc" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler_role.name
}