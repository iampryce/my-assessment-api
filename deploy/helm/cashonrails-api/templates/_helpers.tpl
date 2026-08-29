{{- define "cashonrails-api.name" -}}
cashonrails-api
{{- end -}}

{{- define "cashonrails-api.labels" -}}
app: {{ include "cashonrails-api.name" . }}
environment: {{ required "environment is required (set via values-<env>.yaml)" .Values.environment }}
{{- end -}}
