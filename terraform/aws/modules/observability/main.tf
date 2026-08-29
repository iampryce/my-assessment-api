terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

# Tag-based VPC discovery, same convention as the SSM target module.
data "aws_vpc" "this" {
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }
  filter {
    name   = "tag:Project"
    values = ["cashonrails-assessment"]
  }
}

################################################################################
# Kubernetes: Prometheus + Grafana + Loki
################################################################################

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }
}

# No persistent volumes, short retention - cost-conscious tradeoff for a validation environment.
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name

  set = [
    {
      name  = "grafana.service.type"
      value = "ClusterIP"
    },
    {
      name  = "prometheus.service.type"
      value = "ClusterIP"
    },
    {
      name  = "prometheus.prometheusSpec.retention"
      value = var.metrics_retention
    },
    {
      name  = "grafana.persistence.enabled"
      value = "false"
    },
    # Grafana admin password: chart auto-generates it into a Secret, never set here.
  ]
}

resource "helm_release" "loki_stack" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_stack_chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name

  set = [
    {
      name  = "loki.persistence.enabled"
      value = "false"
    },
    {
      name  = "loki.config.table_manager.retention_period"
      value = "${var.logs_retention_hours}h"
    },
    {
      name  = "promtail.enabled"
      value = "true"
    },
    {
      name  = "grafana.enabled"
      value = "false" # reuse the Grafana already installed by kube-prometheus-stack, not a second instance
    },
  ]
}

################################################################################
# AWS: VPC Flow Logs -> CloudWatch Logs
################################################################################
# CloudTrail/GuardDuty deliberately not added here - account-wide, not per-VPC; see final report.

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc-flow-logs/cashonrails-aws-${var.environment}"
  retention_in_days = var.flow_log_retention_days

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name               = "cashonrails-aws-${var.environment}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role[0].json

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}

data "aws_iam_policy_document" "flow_logs_delivery" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs_delivery" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name   = "cashonrails-aws-${var.environment}-vpc-flow-logs-delivery"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs_delivery[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id                   = data.aws_vpc.this.id
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  traffic_type             = "ALL"
  max_aggregation_interval = 600 # 10 min - cheaper than the 1 min default, sufficient for a validation env

  tags = {
    Environment = var.environment
    Project     = "cashonrails-assessment"
    Purpose     = "aws-validation"
  }
}
