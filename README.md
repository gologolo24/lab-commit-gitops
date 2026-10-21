# lab-commit-gitops

GitOps source of truth for the **AWS Lab – EKS Scaling & Pipeline** assignment (Commit).
Argo CD watches this repo and syncs the EKS cluster to match it.

> 🚧 Work in progress. The review guide lives in [lab-commit-infra](https://github.com/gologolo24/lab-commit-infra).

## Planned layout

```
apps/        Argo CD Applications (app-of-apps): monitoring, keda, backend, frontend, dashboards, loadgen
charts/      Helm 3 charts: frontend, backend, loadgen (k6)
values/      Values for third-party charts (kube-prometheus-stack, KEDA)
dashboards/  Grafana dashboards as code
```

## Who can access this repo

- **Argo CD** reads it with a read-only deploy key.
- **CodeBuild** (frontend/backend pipelines) only updates image tags, using a write deploy key that works for this repo alone.

## Related repositories

- [lab-commit-infra](https://github.com/gologolo24/lab-commit-infra): Terraform and the review guide
- [lab-commit-app](https://github.com/gologolo24/lab-commit-app): application source code
