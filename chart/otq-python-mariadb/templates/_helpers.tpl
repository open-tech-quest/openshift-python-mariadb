{{- define "otq.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "otq.app.name" -}}{{ include "otq.fullname" . | trunc 59 | trimSuffix "-" }}-app{{- end -}}
{{- define "otq.db.name" -}}{{ include "otq.fullname" . | trunc 55 | trimSuffix "-" }}-mariadb{{- end -}}
{{- define "otq.secret.name" -}}{{ include "otq.fullname" . }}{{- end -}}

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

{{- define "otq.db.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}-mariadb
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

{{/*
Return a value from: explicit .Values setting > existing Secret key > random string.
Usage: include "otq.secretValue" (dict "ctx" . "key" "challenge-flag" "value" .Values.challenge.flag "length" 16)
*/}}
{{- define "otq.secretValue" -}}
{{- if .value -}}
{{- .value -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .ctx.Release.Namespace (include "otq.secret.name" .ctx) -}}
{{- if and $existing $existing.data (hasKey $existing.data .key) -}}
{{- index $existing.data .key | b64dec -}}
{{- else -}}
{{- randAlphaNum (int .length) -}}
{{- end -}}
{{- end -}}
{{- end -}}
