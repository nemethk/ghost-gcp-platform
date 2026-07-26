{{- define "ghost.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "ghost.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ghost.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ghost.labels" -}}
app.kubernetes.io/name: {{ include "ghost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "ghost.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ghost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
