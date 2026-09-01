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
    random = {
      source = "hashicorp/random"
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

# Webhook lives in a Secret, never in Helm values/state as plaintext - Alertmanager reads it via
# slack_api_url_file, mounted from this Secret below.
resource "kubernetes_secret_v1" "alertmanager_slack" {
  count = var.slack_webhook_url != "" ? 1 : 0

  metadata {
    name      = "alertmanager-slack"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "webhook-url" = var.slack_webhook_url
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

  # Routes every firing/resolved alert to Slack. Only wired up once a webhook Secret actually
  # exists, so the chart's default receiver stays in place until slack_webhook_url is set.
  values = var.slack_webhook_url != "" ? [yamlencode({
    alertmanager = {
      alertmanagerSpec = {
        secrets = [kubernetes_secret_v1.alertmanager_slack[0].metadata[0].name]
      }
      config = {
        global = {
          slack_api_url_file = "/etc/alertmanager/secrets/${kubernetes_secret_v1.alertmanager_slack[0].metadata[0].name}/webhook-url"
        }
        # route.routes and receivers are both lists - Helm's values merge replaces lists wholesale
        # rather than merging them, so both must be fully self-contained here. Confirmed live: an
        # earlier version that omitted "routes" kept the chart's default Watchdog sub-route (which
        # still pointed at "null"), while replacing "receivers" dropped the "null" receiver
        # definition it depended on, producing "undefined receiver \"null\" used in route" and
        # silently breaking the operator's reconcile of the whole Alertmanager object.
        route = {
          receiver = "slack"
          group_by = ["alertname", "severity"]
          routes = [
            {
              receiver = "null"
              matchers = ["alertname = \"Watchdog\""]
            }
          ]
        }
        receivers = [
          {
            name = "null"
          },
          {
            name = "slack"
            slack_configs = [
              {
                channel       = var.slack_channel
                send_resolved = true
                # "default" is a Sprig function (Helm templates), not available in Alertmanager's
                # plain Go text/template engine - confirmed live via "function \"default\" not
                # defined" notify errors. Use built-in if/else instead.
                title = "{{ if .CommonAnnotations.summary }}{{ .CommonAnnotations.summary }}{{ else }}{{ .CommonLabels.alertname }}{{ end }}"
                text  = "{{ .CommonAnnotations.description }}"
              }
            ]
          }
        ]
      }
    }
  })] : []
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

################################################################################
# Optional public Ingress for Grafana - second auth layer on top of its own login
################################################################################

resource "random_password" "grafana_basic_auth" {
  count   = var.enable_ingress ? 1 : 0
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "grafana_basic_auth" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "grafana-basic-auth"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    auth = "admin:${bcrypt(random_password.grafana_basic_auth[0].result)}"
  }
}

# Grafana's chart service serves plain HTTP on port 80 - no backend-protocol override needed.
resource "kubernetes_ingress_v1" "grafana" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    annotations = merge(
      var.acm_tls_termination ? {
        # NLB already terminated TLS with an ACM cert - nginx sees plain HTTP, don't redirect it back to HTTPS.
        "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
        } : {
        "cert-manager.io/cluster-issuer" = var.cluster_issuer_name
      },
      {
        "nginx.ingress.kubernetes.io/auth-type"        = "basic"
        "nginx.ingress.kubernetes.io/auth-secret"      = kubernetes_secret_v1.grafana_basic_auth[0].metadata[0].name
        "nginx.ingress.kubernetes.io/auth-secret-type" = "auth-file"
      }
    )
  }

  spec {
    ingress_class_name = var.ingress_class_name

    dynamic "tls" {
      for_each = var.acm_tls_termination ? [] : [1]
      content {
        hosts       = [var.ingress_host]
        secret_name = "grafana-ingress-tls"
      }
    }

    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
