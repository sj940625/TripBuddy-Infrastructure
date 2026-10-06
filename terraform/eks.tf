# ==========================================
# 1. EKS 클러스터(Control Plane) IAM 역할
# ==========================================
resource "aws_iam_role" "eks_cluster_role" {
  name = "ai-travel-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# ==========================================
# 2. Amazon EKS 클러스터
# ==========================================
resource "aws_eks_cluster" "main" {
  name     = "ai-travel-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.34"

  vpc_config {
    subnet_ids = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "ai-travel-eks-cluster"
  }
}

# ==========================================
# 3. EKS 워커 노드(Node Group) IAM 역할
# ==========================================
resource "aws_iam_role" "eks_node_role" {
  name = "ai-travel-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# ==========================================
# 4. EKS 관리형 노드 그룹
# ==========================================
resource "aws_eks_node_group" "main_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "ai-travel-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  # Control Plane과 동일하게 1.31로 업그레이드
  version = "1.34"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.large"]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 5
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name = "ai-travel-worker-node"
  }
}

# ==========================================
# 5. EKS 접속용 출력값
# ==========================================
output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.main.name
}

output "eks_kubeconfig_cmd" {
  description = "쿠버네티스 CLI(kubectl) 연동 명령어"
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name ${aws_eks_cluster.main.name}"
}