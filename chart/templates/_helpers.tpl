{{/*
Expand the name of the chart.
*/}}
{{- define "kubetrust.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kubetrust.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kubetrust.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubetrust.labels" -}}
helm.sh/chart: {{ include "kubetrust.chart" . }}
{{ include "kubetrust.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubetrust.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubetrust.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: kubetrust
{{- end }}

{{/*
Create the name of the service account to use for cert generation
*/}}
{{- define "kubetrust.certgen.serviceAccountName" -}}
{{- if .Values.certGenerator.serviceAccount.create }}
{{- default (printf "%s-certgen" (include "kubetrust.fullname" .)) .Values.certGenerator.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.certGenerator.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the name of the TLS secret
*/}}
{{- define "kubetrust.webhookTLSSecret" -}}
{{- if .Values.webhook.tls.existingSecret }}
{{- .Values.webhook.tls.existingSecret }}
{{- else }}
{{- printf "%s-webhook-tls" (include "kubetrust.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Get the name of the CA ConfigMap
*/}}
{{- define "kubetrust.caConfigMap" -}}
{{- .Values.webhook.caInjection.configMapName }}
{{- end }}

{{/*
Get the webhook service name
*/}}
{{- define "kubetrust.webhookServiceName" -}}
{{- default (include "kubetrust.fullname" .) .Values.webhook.service.name }}
{{- end }}
