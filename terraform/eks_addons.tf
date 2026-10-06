# ==========================================
# EKS Managed Add-ons
# ==========================================

# VPC CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = "v1.22.4-eksbuild.3"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.main_nodes
  ]

  tags = {
    Name = "ai-travel-vpc-cni"
  }
}

# CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = "v1.12.4-eksbuild.31"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.main_nodes
  ]

  tags = {
    Name = "ai-travel-coredns"
  }
}

# kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = "v1.34.6-eksbuild.25"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.main_nodes
  ]

  tags = {
    Name = "ai-travel-kube-proxy"
  }
}