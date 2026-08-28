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
}

resource "aws_iam_role_policy" "github_apply_custom" {
  name   = "cashonrails-github-actions-apply-custom"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.github_apply_custom.json
}
