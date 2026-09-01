data "aws_caller_identity" "current" {}

locals {
  name                        = "cashonrails-aws-${var.environment}"
  apply_role_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-github-actions-apply"
  app_cicd_role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-github-actions-app-cicd"
  platform_bootstrap_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-github-actions-platform-bootstrap"
}

# EKS's in-tree cloud provider runs on the managed control plane under the cluster's own service
# role (not the node role, not any GitHub Actions role) - AmazonEKSClusterPolicy covers enough to
# provision a new LoadBalancer Service, but not to modify an existing listener to attach a cert.
# Scoped to NLB listeners account-wide since the specific ARN doesn't exist until Kubernetes
# creates the Service - same class of constraint as bootstrap's AcmCertificateLifecycle statement.
data "aws_iam_policy_document" "nlb_listener_certificate" {
  statement {
    sid    = "NlbListenerCertificateManagement"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
    ]
    resources = ["arn:aws:elasticloadbalancing:*:${data.aws_caller_identity.current.account_id}:listener/net/*/*/*"]
  }
}

resource "aws_iam_policy" "nlb_listener_certificate" {
  name   = "${local.name}-nlb-listener-certificate"
  policy = data.aws_iam_policy_document.nlb_listener_certificate.json
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

  # Lets the in-tree cloud provider (running as the cluster's own role) attach the ACM cert to the
  # ingress-nginx NLB's listener - see aws_iam_policy.nlb_listener_certificate above.
  iam_role_additional_policies = {
    NlbListenerCertificateManagement = aws_iam_policy.nlb_listener_certificate.arn
  }

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
    # Prefix delegation raises per-node pod density well above the default ENI/IP
    # ceiling (17 pods on t3.medium) - needed so the full observability stack
    # (Prometheus/Grafana/Loki/Alertmanager) plus system DaemonSets fit on 2
    # small on-demand nodes without resizing or adding more of them. Free -
    # just assigns /28 IP prefixes to ENIs instead of individual IPs.
    # Existing nodes must be replaced to pick up the new kubelet --max-pods
    # value, which is computed at bootstrap time.
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
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
  # Personal/admin access entries deliberately do NOT live here - this module is fully
  # reconciled by CI (eks-core.yml) on every dispatch, and a local-only value (like an
  # individual operator's admin_principal_arns used to be) gets silently deleted the
  # next time CI applies with that variable at its empty default. See
  # terraform/aws/envs/staging/admin-access for the isolated-state home for those.
  access_entries = {
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
  }

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
