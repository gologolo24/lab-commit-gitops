# lab-commit-gitops

GitOps source of truth for the **AWS Lab – EKS Scaling & Pipeline** assignment (Commit).
Argo CD watches this repo and keeps the EKS cluster in sync with it.

> The review guide lives in [lab-commit-infra](https://github.com/gologolo24/lab-commit-infra).

## How folders become Argo CD Applications

There are no hand-written Application manifests. Two **ApplicationSets**, created by Terraform
(infra repo, `50-cluster-bootstrap`), generate one Application per folder:

| ApplicationSet | Reads | AppProject (guardrails) |
|---|---|---|
| `platform` | `platform/<name>/config.yaml` | `platform`: only its namespaces (monitoring, keda); may install CRDs |
| `apps` | `apps/<name>/config.yaml` | `apps`: only `lab-commit` and `loadgen`; namespaced resources only |

Each ApplicationSet is a matrix of *clusters with an `env` label* × *folders*. A new environment
is a new labelled cluster plus `envs/<env>/values.yaml` files, with no new manifests.
Application names are `<env>-<folder>`, for example `lab-monitoring`.

`config.yaml` in each folder:

```yaml
namespace: monitoring        # where it runs
autoSync: true               # false = sync by hand in Argo CD (loadgen)
serverSideApply: true        # optional, for large CRDs
podSecurity: restricted      # optional namespace Pod Security level (default: baseline)
chart:                       # optional: an upstream Helm chart
  repoURL: https://prometheus-community.github.io/helm-charts
  name: kube-prometheus-stack
  version: 92.11.0
# no "chart:" block = the folder itself is a Helm chart
```

Values: `<folder>/values.yaml`, then `<folder>/envs/<env>/values.yaml` (both optional).

## Layout

```
platform/
  monitoring/          kube-prometheus-stack (Prometheus, Grafana, kube-state-metrics), tuned for Fargate
  monitoring-config/   Grafana admin login via External Secrets + dashboards as code
  keda/                KEDA (scales the frontend on requests/s)
apps/                  frontend, backend, loadgen (added in Step I)
```

## Secrets

No secret values in this repo. Secrets live in AWS Secrets Manager and are synced by
**External Secrets**: each namespace has its own `SecretStore` whose IRSA role can read only
that namespace's secrets.

## Who can access this repo

- **Argo CD** reads it with a read-only deploy key.
- **CodeBuild** (frontend/backend pipelines) only updates image tags, using a write deploy key that works for this repo alone.

## Related repositories

- [lab-commit-infra](https://github.com/gologolo24/lab-commit-infra): Terraform and the review guide
- [lab-commit-app](https://github.com/gologolo24/lab-commit-app): application source code
