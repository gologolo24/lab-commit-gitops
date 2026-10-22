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
| `apps` | `apps/<name>/config.yaml` | `apps`: only `lab-commit` and `loadgen`; namespaced resources only (plus their Namespace) |

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
apps/
  backend/             reads the value from RDS (IAM auth, verified TLS); ClusterIP only; DB setup job
  frontend/            "Hello Lab-Commit v<version>" + the DB value; HTTPS Ingress; KEDA autoscaling
  loadgen/             k6 load test through the HTTPS URL (manual sync)
```

## Apps

| App | Argo CD | What runs | Security |
|---|---|---|---|
| `lab-backend` | auto sync | 1. `db-migrate` Job (Sync hook, wave -1): table, seed value 5, read-only user `app_reader`. 2. Deployment (2 pods), PDB, ServiceMonitor. | IRSA: `backend` may only `rds-db:connect` as `app_reader`; `db-migrator` may only read the RDS master secret. Security Groups for Pods: only pods labelled `lab-commit/db-access` get the security group RDS allows. |
| `lab-frontend` | auto sync | Deployment (no `replicas`: KEDA owns it), Ingress `lab-commit-task.<zone>` on the shared internal ALB (443 only, `/metrics` blocked), ServiceMonitor, KEDA ScaledObject. | No AWS or Kubernetes API access (`automountServiceAccountToken: false`). |
| `lab-loadgen` | **manual**: press SYNC to start a test | k6 Job (Sync hook) at 8 → 15 → 25 → 45 → 0 requests/s, through `https://lab-commit-task.<zone>/`; the lab CA comes from SSM via External Secrets. | Its SecretStore may read only the CA parameter; the k6 pod gets the security group the ALB allows. |

All pods: Pod Security `restricted` (non-root, read-only root filesystem, no capabilities,
`RuntimeDefault` seccomp) and requests = limits (Fargate sizes each pod from its requests).

**Autoscaling:** KEDA queries Prometheus for
`sum(rate(http_requests_total{namespace="lab-commit",service="frontend",handler="/"}[1m]))`
(page loads per second) and keeps `ceil(rate / 10)` frontend pods, between 1 and 4.
It adds at most one pod every 30 s and removes one every 30 s after 60 s of lower load.

**Releases:** the CodePipelines change only `image.tag` in `apps/<service>/envs/<env>/values.yaml`.
Argo CD then rolls out the new version (backend: the migration job runs first).

## Checks

Every PR runs **gitleaks** and **chart-checks** (`helm lint --strict` + `helm template` for each
local chart with each `envs/<env>/values.yaml`).

## Secrets

No secret values and no certificates in this repo. Secrets live in AWS Secrets Manager (the
lab CA certificate in SSM Parameter Store) and are synced by **External Secrets**: each
namespace has its own `SecretStore` whose IRSA role can read only that namespace's items.
The database needs no stored secret at all: the backend logs in with 15-minute IAM tokens.

## Who can access this repo

- **Argo CD** reads it with a read-only deploy key.
- **CodeBuild** (frontend/backend pipelines) only updates image tags, using a write deploy key that works for this repo alone.

## Related repositories

- [lab-commit-infra](https://github.com/gologolo24/lab-commit-infra): Terraform and the review guide
- [lab-commit-app](https://github.com/gologolo24/lab-commit-app): application source code
