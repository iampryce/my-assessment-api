data "aws_caller_identity" "current" {}

# Versioned, encrypted, private Terraform state bucket; native S3 locking via use_lockfile (Terraform 1.10+), no DynamoDB needed.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "cashonrails-terraform-state-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced" # disables ACLs entirely
  }
}

data "aws_iam_policy_document" "terraform_state_deny_insecure_transport" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state_deny_insecure_transport.json
}

# GitHub OIDC provider for short-lived role assumption; thumbprint_list is required by schema but unused by AWS since July 2023.

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Read-only role for pull_request-triggered plans; GitHub's PR sub claim is stable and repo-wide (no branch/PR number).

data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:pull_request"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name               = "cashonrails-github-actions-plan"
  assume_role_policy = data.aws_iam_policy_document.github_plan_trust.json
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# S3-native locking needs PutObject/DeleteObject on the two .tflock objects only, even for a read-only plan.

data "aws_iam_policy_document" "github_plan_lockfile" {
  statement {
    sid    = "TerraformStateLockFiles"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/aws/staging/terraform.tfstate.tflock",
      "${aws_s3_bucket.terraform_state.arn}/aws/production/terraform.tfstate.tflock",
    ]
  }
}

resource "aws_iam_role_policy" "github_plan_lockfile" {
  name   = "cashonrails-github-actions-plan-lockfile"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_lockfile.json
}

# Apply role, assumed only under the staging/production GitHub Environments; production approval is enforced by GitHub Environment protection, not this trust policy.

data "aws_iam_policy_document" "github_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:staging",
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_apply" {
  name               = "cashonrails-github-actions-apply"
  assume_role_policy = data.aws_iam_policy_document.github_apply_trust.json
}

# Interim apply-role scope: managed policies where reasonable (VPC/RDS), custom policy for EKS/IAM/KMS/S3-state where none exists for the caller; not AdministratorAccess.

resource "aws_iam_role_policy_attachment" "github_apply_vpc" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

resource "aws_iam_role_policy_attachment" "github_apply_rds" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

data "aws_iam_policy_document" "github_apply_custom" {
  statement {
    sid       = "EKSClusterLifecycle"
    effect    = "Allow"
    actions   = ["eks:*"]
    resources = ["*"] # no narrower managed policy exists for the caller creating the cluster
  }

  statement {
    sid     = "SelfAndServiceLinkedRoleGetRole"
    effect  = "Allow"
    actions = ["iam:GetRole"]
    resources = [
      aws_iam_role.github_apply.arn,
      # EKS's CreateNodegroup checks this pre-existing service-linked role exists via the caller's own iam:GetRole.
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup",
    ]
  }

  statement {
    sid    = "IAMScopedToProjectRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:GetInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-aws-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/cashonrails-aws-*",
    ]
  }

  statement {
    sid    = "IAMOidcProviderForIRSA"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    # Per-cluster OIDC provider ARN is only known after cluster creation, so this can't be scoped narrower.
    resources = ["*"]
  }

  statement {
    sid    = "KMSForEksSecretsEncryption"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ScheduleKeyDeletion",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
      "kms:TagResource",
      "kms:ListResourceTags",
    ]
    # kms:CreateKey cannot be scoped to a not-yet-existing key ARN.
    resources = ["*"]
  }

  statement {
    sid       = "EksAmiSsmLookup"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*::parameter/aws/service/eks/*"]
  }

  statement {
    sid    = "EksControlPlaneLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteLogGroup",
      "logs:TagResource",
      "logs:ListTagsForResource",
    ]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/cashonrails-aws-*"]
  }

  statement {
    sid       = "LogsDescribeReadback"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"] # this action's resource-level permission model doesn't recognize a log-group ARN
  }

  statement {
    sid       = "KmsAliasReadback"
    effect    = "Allow"
    actions   = ["kms:ListAliases"]
    resources = ["*"] # kms:ListAliases does not support resource-level restriction
  }

  statement {
    sid       = "EipReadback"
    effect    = "Allow"
    actions   = ["ec2:DescribeAddressesAttribute"]
    resources = ["*"] # this action does not support resource-level scoping
  }

  statement {
    sid       = "Ec2InstanceTypeReadbackForSsmTarget"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstanceTypes"]
    resources = ["*"] # this action does not support resource-level scoping
  }

  statement {
    sid     = "Ec2InstanceAttributeReadbackForSsmTarget"
    effect  = "Allow"
    actions = ["ec2:DescribeInstanceAttribute"] # single action covers all per-attribute reads (shutdown behavior, userData, etc.)
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
    ]
  }

  statement {
    sid       = "Ec2InstanceCreditSpecReadbackForSsmTarget"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstanceCreditSpecifications"]
    resources = ["*"] # bulk/filterable Describe action, same class as DescribeInstanceTypes - t3.micro is burstable so this is read every refresh
  }

  statement {
    sid       = "Ec2VolumeReadbackForSsmTarget"
    effect    = "Allow"
    actions   = ["ec2:DescribeVolumes"]
    resources = ["*"] # bulk/filterable Describe action, same class as DescribeInstanceTypes - reads the instance's root_block_device
  }

  statement {
    sid    = "Ec2LaunchTemplateCreate"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
    ]
    # None of these three actions support resource-level scoping (confirmed live via AWS's AccessDenied response shape).
    resources = ["*"]
  }

  statement {
    sid    = "Ec2LaunchTemplateLifecycle"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplateVersion",
      "ec2:ModifyLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
    ]
    # Launch-template ARNs are ID-based, not name-based, so this wildcard-on-ID is the narrowest scope available.
    resources = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:launch-template/*"]
  }

  statement {
    sid     = "Ec2RunInstancesForEksNodeGroup"
    effect  = "Allow"
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:volume/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:network-interface/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:subnet/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:security-group/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:launch-template/*",
      # AMIs are AWS/publicly-owned, not account-owned, so this resource type can't be account-scoped.
      "arn:aws:ec2:*::image/*",
    ]
    condition {
      test     = "StringLike"
      variable = "ec2:LaunchTemplate"
      values   = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:launch-template/*"]
    }
  }

  statement {
    sid    = "IAMPolicyLifecycleForEksIrsa"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cashonrails-aws-*"]
  }

  statement {
    sid    = "SecretsManagerForRdsManagedPassword"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:TagResource",
    ]
    # rds!db-* is RDS's own reserved prefix for these secrets; the actual name isn't known until the DB instance exists.
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"]
  }

  statement {
    sid       = "TerraformStateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid    = "TerraformStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/aws/staging/*",
      "${aws_s3_bucket.terraform_state.arn}/aws/production/*",
    ]
    # The use_lockfile lock object lives under the same key prefix as the state file, so no separate permission is needed.
  }

  statement {
    sid    = "EcrRepositoryLifecycle"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:PutLifecyclePolicy",
      "ecr:GetLifecyclePolicy",
      "ecr:DeleteLifecyclePolicy",
      "ecr:PutImageTagMutability",
      "ecr:PutImageScanningConfiguration",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:ListTagsForResource",
    ]
    # Unlike EKS/KMS, ECR repository ARNs are name-based and known ahead of creation, so every action here is scoped.
    resources = ["arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/cashonrails-aws-*"]
  }
}

resource "aws_iam_role_policy" "github_apply_custom" {
  name   = "cashonrails-github-actions-apply-custom"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.github_apply_custom.json
}

# App CI/CD role — separate from the Terraform apply role; pushes images and deploys to EKS, never touches infrastructure.

data "aws_iam_policy_document" "github_app_cicd_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/main",
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:staging",
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_app_cicd" {
  name               = "cashonrails-github-actions-app-cicd"
  assume_role_policy = data.aws_iam_policy_document.github_app_cicd_trust.json
}

data "aws_iam_policy_document" "github_app_cicd_custom" {
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # docker login has no resource-level scoping
  }

  statement {
    sid    = "EcrPushToAppRepositories"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [
      "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/cashonrails-aws-staging",
      "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/cashonrails-aws-production",
    ]
  }

  statement {
    sid     = "EksClusterDiscovery"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/cashonrails-aws-staging",
      "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/cashonrails-aws-production",
    ]
  }

  statement {
    sid    = "ReadRdsManagedSecretForAppConfig"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"]
  }

  statement {
    sid       = "DiscoverCicdSsmTarget"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"] # bulk-enumeration action, no resource-level scoping - same class as other unscoped Describe* actions in this policy
  }

  # Split in two - the tag condition only applies to the instance; the AWS-owned document has no tags.
  statement {
    sid     = "StartSessionToCicdSsmTargetInstance"
    effect  = "Allow"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Purpose"
      values   = ["cicd-ssm-target"]
    }
  }

  statement {
    sid       = "StartSessionToCicdSsmTargetDocument"
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ssm:*::document/AWS-StartPortForwardingSessionToRemoteHost"] # AWS-owned public document - no account ID in its ARN, no tags to condition on
  }

  statement {
    sid     = "TerminateOwnSsmSession"
    effect  = "Allow"
    actions = ["ssm:TerminateSession"]
    # ${aws:username} is not populated for assumed-role sessions (GitHub OIDC is always an assumed role) - "GitHubActions" is the confirmed, unoverridden role-session-name for every workflow in this repo.
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:session/GitHubActions-*"]
  }
}

resource "aws_iam_role_policy" "github_app_cicd_custom" {
  name   = "cashonrails-github-actions-app-cicd-custom"
  role   = aws_iam_role.github_app_cicd.id
  policy = data.aws_iam_policy_document.github_app_cicd_custom.json
}

# Platform-bootstrap role — installs/upgrades the cluster platform layer (Argo CD, ingress-nginx,
# cert-manager) only. Distinct from both the infra-apply role (VPC/EKS/RDS/ECR) and the app-cicd
# role (namespace-scoped app deploys), so neither of those ever needs cluster-scoped Kubernetes
# access. Gated behind its own GitHub Environment ("platform") so it requires the same kind of
# deliberate manual approval as production, since it is rare and cluster-wide by nature.
#
# Its AWS-side IAM policy stays deliberately narrow (EKS discovery + the same SSM-tunnel actions
# app-cicd already has) - the actual cluster-admin-equivalent power comes from the EKS access
# entry's Kubernetes RBAC association (see modules/eks), not from AWS IAM actions here.

data "aws_iam_policy_document" "github_platform_bootstrap_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # No GitHub Environment named "platform" exists - matches staging/production like github_apply does.
      values = [
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:staging",
        "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_platform_bootstrap" {
  name               = "cashonrails-github-actions-platform-bootstrap"
  assume_role_policy = data.aws_iam_policy_document.github_platform_bootstrap_trust.json
}

data "aws_iam_policy_document" "github_platform_bootstrap_custom" {
  statement {
    sid     = "EksClusterDiscovery"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/cashonrails-aws-staging",
      "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/cashonrails-aws-production",
    ]
  }

  statement {
    sid       = "DiscoverCicdSsmTarget"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"] # bulk-enumeration action, no resource-level scoping - same class as other unscoped Describe* actions in this policy
  }

  # Split in two - the tag condition only applies to the instance; the AWS-owned document has no tags.
  statement {
    sid     = "StartSessionToCicdSsmTargetInstance"
    effect  = "Allow"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Purpose"
      values   = ["cicd-ssm-target"]
    }
  }

  statement {
    sid       = "StartSessionToCicdSsmTargetDocument"
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ssm:*::document/AWS-StartPortForwardingSessionToRemoteHost"] # AWS-owned public document - no account ID in its ARN, no tags to condition on
  }

  statement {
    sid       = "TerminateOwnSsmSession"
    effect    = "Allow"
    actions   = ["ssm:TerminateSession"]
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:session/GitHubActions-*"]
  }

  # Platform-layer state only - literal keys, not a wildcard, so this role can't touch envs/*'s own state.
  statement {
    sid    = "PlatformStateBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["aws/staging/platform/*", "aws/production/platform/*"]
    }
  }

  statement {
    sid    = "PlatformStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/aws/staging/platform/terraform.tfstate",
      "${aws_s3_bucket.terraform_state.arn}/aws/staging/platform/terraform.tfstate.tflock",
      "${aws_s3_bucket.terraform_state.arn}/aws/production/platform/terraform.tfstate",
      "${aws_s3_bucket.terraform_state.arn}/aws/production/platform/terraform.tfstate.tflock",
    ]
  }

  # Real hosted_zone_id isn't known yet (no domain owned), so scoped to the resource type, not all of route53:*.
  statement {
    sid    = "DnsRecordManagement"
    effect = "Allow"
    actions = [
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }

  statement {
    sid       = "DnsChangePropagationStatus"
    effect    = "Allow"
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"] # change IDs are assigned by AWS at request time, unknowable ahead of time
  }

  # Observability module's own tag-based VPC lookup (data "aws_vpc" "this").
  statement {
    sid       = "VpcDiscoveryForObservability"
    effect    = "Allow"
    actions   = ["ec2:DescribeVpcs"]
    resources = ["*"] # bulk/filterable Describe action, same class as DescribeInstanceTypes
  }

  # Same data source also reads per-attribute fields (e.g. enableDnsHostnames) via a separate call.
  statement {
    sid       = "VpcAttributeReadbackForObservability"
    effect    = "Allow"
    actions   = ["ec2:DescribeVpcAttribute"]
    resources = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:vpc/*"]
  }

  # Observability module's VPC Flow Logs - scoped to the VPC logged and the flow-log resource created.
  statement {
    sid    = "VpcFlowLogsLifecycle"
    effect = "Allow"
    actions = [
      "ec2:CreateFlowLogs",
      "ec2:DeleteFlowLogs",
    ]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:vpc/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*",
    ]
  }

  # CreateFlowLogs applies tags via a separate call, not inline.
  statement {
    sid    = "VpcFlowLogsTagging"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"]
  }

  statement {
    sid       = "VpcFlowLogsReadback"
    effect    = "Allow"
    actions   = ["ec2:DescribeFlowLogs"]
    resources = ["*"] # this action does not support resource-level scoping
  }

  # Destination log group: /aws/vpc-flow-logs/cashonrails-aws-{environment}, module also tags it.
  statement {
    sid    = "VpcFlowLogsDestinationLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteLogGroup",
      "logs:TagResource",
      "logs:ListTagsForResource",
    ]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc-flow-logs/cashonrails-aws-*"]
  }

  statement {
    sid       = "VpcFlowLogsLogGroupDiscovery"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"] # this action does not support resource-level scoping (same class as LogsDescribeReadback on the apply role)
  }

  # The flow log's delivery role + inline policy - scoped to that exact role-name pattern only.
  statement {
    sid    = "VpcFlowLogsDeliveryRoleLifecycle"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-aws-*-vpc-flow-logs"]
  }

  # PassRole for CreateFlowLogs, narrowed to this role and only when passed to the flow-logs service.
  statement {
    sid    = "PassFlowLogsDeliveryRole"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cashonrails-aws-*-vpc-flow-logs"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_platform_bootstrap_custom" {
  name   = "cashonrails-github-actions-platform-bootstrap-custom"
  role   = aws_iam_role.github_platform_bootstrap.id
  policy = data.aws_iam_policy_document.github_platform_bootstrap_custom.json
}
