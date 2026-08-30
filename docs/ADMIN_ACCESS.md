# Cashonrails Admin Access

## Staging Environment

### Application

https://api.staging.cashonrails.rivetrecords.online

### Argo CD

https://argocd.staging.cashonrails.rivetrecords.online

### Grafana

https://grafana.staging.cashonrails.rivetrecords.online

## Kubernetes Access

The EKS API endpoint is private.

Administrative Kubernetes access is provided through AWS Systems Manager
rather than a publicly accessible Kubernetes API endpoint.

## Argo CD

Argo CD is deployed inside the EKS cluster and exposed through the staging
ingress.

Access credentials are provided separately through the assessment submission
channel.

## Grafana

Grafana is deployed as part of the platform observability stack and exposed
through the staging ingress.

Access credentials are provided separately through the assessment submission
channel.

## AWS Access

AWS infrastructure is managed through the configured GitHub OIDC roles and
Terraform workflows.

No long-lived AWS credentials are stored in the repository.

## Environment

Environment: staging
Region: us-east-1

Production infrastructure was not deployed.
