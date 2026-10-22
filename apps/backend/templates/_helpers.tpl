{{- define "backend.selectorLabels" -}}
app.kubernetes.io/name: backend
app.kubernetes.io/part-of: lab-commit
{{- end }}

{{- define "backend.labels" -}}
{{ include "backend.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "backend.image" -}}
{{ required "image.repository is required" .Values.image.repository }}:{{ required "image.tag is required" .Values.image.tag }}
{{- end }}

{{/* Pod Security "restricted": non-root, no privilege escalation, no capabilities. */}}
{{- define "backend.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "backend.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}

{{/* Settings shared by the app and the migration job (see backend/app/config.py). */}}
{{- define "backend.dbEnv" -}}
- name: AWS_REGION
  value: {{ required "region is required" .Values.region | quote }}
- name: DB_HOST
  value: {{ required "db.host is required" .Values.db.host | quote }}
- name: DB_PORT
  value: {{ .Values.db.port | quote }}
- name: DB_NAME
  value: {{ .Values.db.name | quote }}
- name: DB_USER
  value: {{ .Values.db.user | quote }}
{{- end }}
