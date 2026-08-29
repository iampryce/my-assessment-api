# AWS Staging Remediation — Session State

Snapshot for resuming this work if the session closes. Last updated: 2026-08-28.

## Context

Huawei Cloud is the intended final target (Nigeria data-residency requirement).
Huawei account activation is blocked (payment-method issue), so **AWS is a
temporary functional-validation environment only** — it does not satisfy the
data-residency requirement and is not a replacement for Huawei.

A staging `terraform apply` partially failed multiple times as missing
apply-role IAM permissions surfaced one layer at a time. This file tracks
where that recovery currently stands.

## Git state right now

- Branch: `chore/verify-staging-plan` (pushed, PR merged to `main` already for
  the plan-verification commit — see below).
- Uncommitted local change: `terraform/aws/bootstrap/main.tf` — two new IAM
  statements (`Ec2LaunchTemplateCreate`, `Ec2LaunchTemplateLifecycle`) for the
  EC2 launch-template permissions the EKS node group needs. **Applied to AWS
  and verified live; still not committed.**
- Standing rule: never `git push` without explicit approval each time (see
  local memory `git-github-restrictions`); commits only when explicitly told.

## Live AWS state (account 494472951824, us-east-1, staging)

Confirmed created and healthy:
- VPC `vpc-0277f6fa11169db14`, 4 subnets, 3 route tables, IGW, 3 security groups
- NAT gateway `nat-0d0a8d0663c4ea8f6` (using EIP `eipalloc-0c5f02917ae00c075`,
  now correctly associated — untaint fix worked, no duplicate EIP)
- KMS key `f12358bb-6552-42da-b692-6a7867fbbb73` + alias `alias/eks/cashonrails-aws-staging`
- CloudWatch log group `/aws/eks/cashonrails-aws-staging/cluster`
- EKS cluster `cashonrails-aws-staging` — **ACTIVE**
- IRSA OIDC provider, `ClusterEncryption` IAM policy + attachment
- Node-group IAM role `cashonrails-aws-staging-node-*` (+ 3 policy attachments)
- RDS instance `cashonrails-aws-staging-rds` — **available**, master password
  in Secrets Manager
- RDS parameter group + subnet group

Confirmed NOT yet created:
- EC2 launch template for the node group — permission fix is now applied
  (see below); creation just hasn't been attempted again yet
- EKS node group itself (`aws_eks_node_group`) — depends on the launch
  template, never reached
- Production environment — entirely untouched (staging job gates it, and
  staging has never fully succeeded)

## IAM policy state — `cashonrails-github-actions-apply` custom policy

Applied and live in AWS already (in order of discovery):
1. `SelfGetRole` — self-inspection
2. `EksAmiSsmLookup` — SSM AMI parameter lookup
3. `EksControlPlaneLogging` (Create/Put/Delete/Tag/List, scoped) +
   `LogsDescribeReadback` (`*`, unscoped)
4. `KmsAliasReadback` (`*`, unscoped)
5. `EipReadback` (`*`, unscoped)
6. `IAMPolicyLifecycleForEksIrsa` (scoped to `policy/cashonrails-aws-*`)
7. `SecretsManagerForRdsManagedPassword` (scoped to `secret:rds!db-*`)
8. `Ec2LaunchTemplateCreate` (`ec2:CreateLaunchTemplate`,
   `ec2:DescribeLaunchTemplates` — `Resource="*"`, IDs unknown ahead of
   creation / bulk-list action) — **applied, verified live in IAM, re-plan
   confirmed 0 changes**
9. `Ec2LaunchTemplateLifecycle` (`CreateLaunchTemplateVersion`,
   `DescribeLaunchTemplateVersions`, `ModifyLaunchTemplate`,
   `DeleteLaunchTemplate` — scoped to `arn:aws:ec2:*:<account>:launch-template/*`)
   — **applied, verified live in IAM, re-plan confirmed 0 changes**

Also fixed via Terraform code (not IAM): the node-group IAM role name was
overridden (`iam_role_name = "${local.name}-node"`) in
[terraform/aws/modules/eks/main.tf](modules/eks/main.tf) so it matches the
existing `cashonrails-aws-*` IAM scoping instead of the module's default
`default-eks-node-group-*` name — already applied, confirmed live.

## GitHub Actions workflows

- `terraform-plan.yml` — PR-triggered, read-only plan role, safe to run anytime.
- `terraform-deploy.yml` — push-to-main / `workflow_dispatch`, apply role,
  staging auto-applies, production gated by GitHub Environment approval.
  **Auto-applies on staging — do not dispatch casually.**
- `terraform-untaint-staging.yml` — one-time manual recovery tool (already
  used successfully once, to clear 3 resources tainted by an earlier partial
  apply's failed read-backs). Only needed again if a similar tainting recurs.

## Next step when resuming

1. Re-run staging deploy via `terraform-deploy.yml` (`workflow_dispatch`)
   and watch for the launch template + node group to complete.
2. If a new AccessDenied surfaces, follow the same pattern: read-only
   inventory + CloudTrail evidence, prepare the fix, get approval, apply,
   verify — never patch blind, never batch multiple unverified guesses.
