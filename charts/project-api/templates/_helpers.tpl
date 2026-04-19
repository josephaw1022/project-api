{{/*
Expand the name of the chart.
*/}}
{{- define "project-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "project-api.fullname" -}}
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
{{- define "project-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "project-api.labels" -}}
helm.sh/chart: {{ include "project-api.chart" . }}
{{ include "project-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "project-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "project-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "project-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "project-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate certificates
*/}}
{{- define "project-api.certs" -}}
{{- if not (index . "certObj") -}}
{{- $fullName := include "project-api.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $ca := genCA "project-api-ca" 3650 -}}
{{- $cert := genSignedCert (printf "%s.%s.svc" $fullName $namespace) nil (list $fullName (printf "%s.%s" $fullName $namespace) (printf "%s.%s.svc" $fullName $namespace) (printf "%s.%s.svc.cluster.local" $fullName $namespace)) 3650 $ca -}}
{{- $_ := set . "certObj" (dict "ca" $ca "cert" $cert) -}}
{{- end -}}
{{- end -}}
