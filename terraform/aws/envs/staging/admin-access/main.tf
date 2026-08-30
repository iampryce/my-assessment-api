# Standing personal cluster access, isolated on purpose (see backend.tf). Mirrors
# the same policy the old in-module admin_principal_arns used: EKS Edit,
# cluster-scoped - not Admin/ClusterAdmin, least-privilege by design.

resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = var.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_edit" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = var.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}
