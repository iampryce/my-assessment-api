data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Terraform state bucket — versioned, encrypted, fully private. Used by
# infra/aws/envs/staging and infra/aws/envs/production with separate key
# prefixes (aws/staging/terraform.tfstate, aws/production/terraform.tfstate).
#
# Locking: Terraform 1.10+ supports native S3 state locking via the
# backend's `use_lockfile` option (S3 conditional writes), which needs no
# separate DynamoDB table. This account's Terraform is on 1.15.x, so the
# envs use `use_lockfile = true` instead of a DynamoDB lock table.
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# GitHub OIDC provider — lets GitHub Actions assume AWS IAM roles via
# short-lived tokens instead of long-lived access keys.
#
# thumbprint_list is required by this resource's schema, but AWS has
# validated GitHub's OIDC provider against its own trusted CA library
# (not this thumbprint) since July 2023. The value below is GitHub's
# documented root CA thumbprint, kept for schema compatibility only.
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---------------------------------------------------------------------------
# Plan role — assumed only by pull_request-triggered workflows. Read-only:
# a PR can never mutate infrastructure through this role, only inspect it
# for `terraform plan`. GitHub's OIDC sub claim for a pull_request event is
# stable and repo-wide: "repo:<org>/<repo>:pull_request" (no branch/PR
# number in it).
# ---------------------------------------------------------------------------

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
      values   = ["repo:${var.github_org}/${var.github_repo}:pull_request"]
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

# ---------------------------------------------------------------------------
# Apply role — assumed only by workflow jobs running under the "staging" or
# "production" GitHub Environment (sub claim
# "repo:<org>/<repo>:environment:<name>"). The "production" GitHub
# Environment must have required-reviewer protection configured in the
# repo's Settings -> Environments — that is a GitHub-side setting this
# Terraform cannot configure, and is what actually enforces "production
# needs explicit approval" (the IAM trust policy alone only restricts
# *which* GitHub context can assume the role, not who approves the run).
# ---------------------------------------------------------------------------

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
        "repo:${var.github_org}/${var.github_repo}:environment:staging",
        "repo:${var.github_org}/${var.github_repo}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_apply" {
  name               = "cashonrails-github-actions-apply"
  assume_role_policy = data.aws_iam_policy_document.github_apply_trust.json
}

# ---------------------------------------------------------------------------
# Apply role permissions — an interim, documented scope, not a fully
# minimal one. The exact action set that terraform-aws-modules/{vpc,eks,rds}
# invoke is large (EC2, EKS, IAM, KMS, RDS) and not safely enumerable by
# hand without risking a broken apply from a missed permission. This
# attaches AWS-managed policies where a reasonably-scoped one exists
# (VPC, RDS), and a custom policy for EKS/IAM/KMS/S3-state where no
# suitable managed policy exists for the *deploying* principal (the
# managed EKS policies are meant for the cluster/node roles, not the
# caller creating them). IAM role/instance-profile actions are scoped by
# name prefix to this project's naming convention
# ("cashonrails-aws-*") wherever the API allows resource-level scoping;
# EKS OIDC-provider and KMS key creation cannot be scoped to a
# not-yet-existing resource ARN and are left broad, noted below.
#
# This is not AdministratorAccess and touches no unrelated services.
# Tighten further once real plan/apply runs show the exact actions used
# (e.g. via IAM Access Analyzer policy generation).
# ---------------------------------------------------------------------------

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
    # EKS's per-cluster IRSA OIDC provider ARN includes a cluster-specific
    # ID only known after the cluster exists — cannot be scoped ahead of
    # creation.
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
    # The S3-native lock file created by `use_lockfile` lives under the
    # same key prefix as the state file it locks, so no separate
    # permission is needed for locking.
  }
}

resource "aws_iam_role_policy" "github_apply_custom" {
  name   = "cashonrails-github-actions-apply-custom"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.github_apply_custom.json
}
