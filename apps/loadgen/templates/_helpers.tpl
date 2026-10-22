{{- define "loadgen.labels" -}}
app.kubernetes.io/name: loadgen
app.kubernetes.io/part-of: lab-commit
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
