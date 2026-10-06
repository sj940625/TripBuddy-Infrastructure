# =======================================================
# EKS access entries
#
# Team/user-specific IAM ARNs are intentionally not committed.
# Supply them through terraform.tfvars.
# =======================================================
resource "aws_eks_access_entry" "team_access" {
  for_each      = toset(var.eks_admin_user_arns)
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "team_admin_policy" {
  for_each      = toset(var.eks_admin_user_arns)
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.team_access]
}
