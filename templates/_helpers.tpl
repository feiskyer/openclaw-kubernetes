{{/*
Expand the name of the chart.
*/}}
{{- define "openclaw.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openclaw.fullname" -}}
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
{{- define "openclaw.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openclaw.labels" -}}
helm.sh/chart: {{ include "openclaw.chart" . }}
{{ include "openclaw.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openclaw.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openclaw.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openclaw.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "openclaw.secretName" -}}
{{- if .Values.secrets.existingSecret }}
{{- .Values.secrets.existingSecret }}
{{- else }}
{{- include "openclaw.fullname" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap to use
*/}}
{{- define "openclaw.configMapName" -}}
{{- printf "%s-config" (include "openclaw.fullname" .) }}
{{- end }}

{{/*
Create the name of the PVC to use
*/}}
{{- define "openclaw.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- printf "%s-data" (include "openclaw.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Validate that required secrets are provided when not using existing secret
*/}}
{{- define "openclaw.validateSecrets" -}}
{{- if not .Values.secrets.existingSecret }}
{{- if not .Values.secrets.openclawGatewayToken }}
{{- fail "secrets.openclawGatewayToken is required when not using an existing secret" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate autoscaling settings for single-instance app
*/}}
{{- define "openclaw.validateAutoscaling" -}}
{{- if .Values.autoscaling.enabled -}}
{{- if or (ne (int .Values.autoscaling.minReplicas) 1) (ne (int .Values.autoscaling.maxReplicas) 1) -}}
{{- fail "autoscaling.enabled requires minReplicas=1 and maxReplicas=1 for OpenClaw" }}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Pod labels
*/}}
{{- define "openclaw.podLabels" -}}
{{ include "openclaw.selectorLabels" . }}
{{- with .Values.podAnnotations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for ingress
*/}}
{{- define "openclaw.ingress.apiVersion" -}}
{{- if and (.Capabilities.APIVersions.Has "networking.k8s.io/v1") (semverCompare ">= 1.19-0" .Capabilities.KubeVersion.Version) }}
{{- print "networking.k8s.io/v1" }}
{{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1" }}
{{- print "networking.k8s.io/v1beta1" }}
{{- else }}
{{- print "extensions/v1beta1" }}
{{- end }}
{{- end }}

{{/*
LiteLLM fullname
*/}}
{{- define "openclaw.litellm.fullname" -}}
{{- printf "%s-litellm" (include "openclaw.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
LiteLLM ConfigMap name
*/}}
{{- define "openclaw.litellm.configMapName" -}}
{{- printf "%s-litellm-config" (include "openclaw.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
LiteLLM Secret name
*/}}
{{- define "openclaw.litellm.secretName" -}}
{{- printf "%s-litellm" (include "openclaw.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
LiteLLM selector labels
*/}}
{{- define "openclaw.litellm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: litellm
{{- end }}

{{/*
LiteLLM labels
*/}}
{{- define "openclaw.litellm.labels" -}}
helm.sh/chart: {{ include "openclaw.chart" . }}
{{ include "openclaw.litellm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Return true if the ingress supports pathType
*/}}
{{- define "openclaw.ingress.supportsPathType" -}}
{{- if eq (include "openclaw.ingress.apiVersion" .) "networking.k8s.io/v1" }}
{{- print "true" }}
{{- else }}
{{- print "false" }}
{{- end }}
{{- end }}
