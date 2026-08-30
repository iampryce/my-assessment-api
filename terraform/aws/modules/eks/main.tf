data "aws_caller_identity" "current" {}

locals {
  name                        = "cashonrails-aws-${var.environment}"
  apply_role_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-github-actions-apply"
  app_cicd_role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-github-actions-app-cicd"
  platform_bootstrap_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-github-actions-platform-bootstrap"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  endpoint_public_access  = false
  endpoint_private_access = true

  # Without this, the module defaults the cluster's KMS key administrator to "whoever is currently
  # running Terraform" (data.aws_iam_session_context.current), which flips identity - and produces
  # an unrelated plan diff - every time a different principal runs plan/apply. Pinning it to the
  # apply role makes this deterministic; it does not change who is administrator today (this is
  # already the live value) and does not add or remove any permissions.
  kms_key_administrators = [local.apply_role_arn]

  # Lets the CI/CD SSM deployment bridge reach the private API on 443 - the only way this pipeline can deploy without a public endpoint.
  security_group_additional_rules = {
    ingress_cicd_ssm_target = {
      type                     = "ingress"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      source_security_group_id = var.cicd_ssm_target_security_group_id
    }
  }

  addons = {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
  }

  # Namespace-scoped, non-admin access for the app CI/CD role to deploy the application. Argo CD
  # (once installed by platform_bootstrap below) owns "cashonrails" namespace creation via its own
  # in-cluster ClusterRole, so this stays namespace-scoped and never needs widening for app teams.
  #
  # Cluster-scoped access for the platform-bootstrap role only, to install Argo CD/ingress-nginx/
  # cert-manager - all of which need to create CRDs, ClusterRoles/ClusterRoleBindings, and their
  # own namespaces, none of which AmazonEKSEditPolicy (namespace-scoped) permits.
  access_entries = merge({
    app_cicd = {
      principal_arn = local.app_cicd_role_arn
      policy_associations = {
        edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["cashonrails"]
          }
        }
      }
    }
    platform_bootstrap = {
      principal_arn = local.platform_bootstrap_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    }, {
    for idx, arn in var.admin_principal_arns : "admin_${idx}" => {
      principal_arn = arn
      policy_associations = {
        edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  })

  eks_managed_node_groups = {
    default = {
      name          = local.name
      iam_role_name = "${local.name}-node"

      # Temporary SSM diagnostic access - remove unless we decide to keep it.
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = var.subnet_ids
    }
  }

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}
