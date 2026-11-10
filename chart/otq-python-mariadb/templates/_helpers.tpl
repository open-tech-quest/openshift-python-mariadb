{{- define "otq.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "otq.app.name" -}}{{ include "otq.fullname" . | trunc 59 | trimSuffix "-" }}-app{{- end -}}
{{- define "otq.secret.name" -}}{{ .Values.database.existingSecret | default (include "otq.fullname" .) }}{{- end -}}
{{- define "otq.secret.passwordKey" -}}{{ ternary .Values.database.existingSecretPasswordKey "database-password" (not (empty .Values.database.existingSecret)) }}{{- end -}}

{{- define "otq.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "otq.fullname" . }}
{{- end -}}

{{- define "otq.app.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}-app
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Restricted-v2 SCC compatible; OpenShift assigns the UID */}}
{{- define "otq.containerSecurityContext" -}}
allowPrivilegeEscalation: false
runAsNonRoot: true
capabilities:
  drop: ["ALL"]
seccompProfile:
  type: RuntimeDefault
{{- end -}}

