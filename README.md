# Cloud-Native GitOps Platform

A GitOps platform deployed on AWS EKS using Terraform, Helm, ArgoCD, and a full
observability stack (Prometheus, Grafana, Loki, Alertmanager). Taskly integrated (a task management API) as workload.
This platform was built as an Ironhack
DevOps & Cloud Engineering final project.

## Architecture

```
Developer → GitHub → GitHub Actions (test, pip-audit, Trivy, build, push to ECR)
    → update Helm values (image tag) → ArgoCD → auto-sync to staging
    → manual approval gate → promote same image tag to production
    → Amazon EKS → NGINX Ingress → Taskly API → Amazon RDS (PostgreSQL) &
      ElastiCache (Redis) → Prometheus, Grafana, Loki, Alertmanager
```

Staging and production run in the same EKS cluster, separated by namespace
(`taskly-staging`, `taskly-production`), each with its own RDS instance, ElastiCache
cluster, and Kubernetes Secret. See `docs/architecture-diagram.png` for a visual.

## Repository layout

```
taskly/           FastAPI application (Postgres, Redis, Prometheus metrics, JSON logging)
infrastructure/   Terraform: VPC, EKS, RDS, ElastiCache, IRSA, GitHub OIDC
helm/             Helm chart for the Taskly API
argocd/           ArgoCD Application manifests (staging, production)
monitoring/       Grafana dashboard, Prometheus alert rules, Alertmanager config
scripts/          up.sh / down.sh and installers for ArgoCD, monitoring, ingress, DNS
docs/             This documentation
```

## How to provision

Requires: AWS CLI configured, Terraform, kubectl, Helm.

```bash
./scripts/up.sh <your-name>
```

This provisions the VPC, EKS cluster, RDS, ElastiCache, and IRSA roles via Terraform,
creates the `taskly-staging` / `taskly-production` namespaces, and installs ArgoCD,
the `kube-prometheus-stack` (Prometheus, Grafana, Alertmanager), Loki, NGINX Ingress,
and external-dns.

To tear everything down:

```bash
./scripts/down.sh <your-name>
```

`down.sh` removes any Kubernetes-provisioned LoadBalancer services first (Terraform
can't see these), then runs `terraform destroy`.

## How to deploy

Deployment is fully GitOps-driven — there is no manual `kubectl apply` in the normal
flow.

1. Push to `main`.
2. GitHub Actions runs tests, `pip-audit`, builds the image, scans it with Trivy
   (blocks on CRITICAL findings), and pushes it to ECR tagged with the commit SHA.
3. The pipeline updates `helm/values-staging.yaml` with that image tag and commits it
   back to the repo. ArgoCD detects the change and syncs `taskly-staging`
   automatically.
4. The `deploy-production` job waits for manual approval (GitHub Environments —
   Settings → Environments → production → required reviewers). Once approved, it
   updates `helm/values-production.yaml` with the **same** image tag (never rebuilt)
   and ArgoCD syncs `taskly-production`.

See `docs/rollback.md` for how to revert a bad deploy.

## How to access dashboards

**Grafana:**

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Open `http://localhost:3000` (default `admin` / `admin`, unless changed). The
**Taskly API** dashboard shows request rate, error rate, p95 latency, active tasks,
tasks created, and per-path breakdowns, with a namespace selector to switch between
staging and production.

**Prometheus:**

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

`http://localhost:9090` — check `/targets` to confirm scrape health, `/alerts` for
current alert state.

**Loki (logs), via Grafana Explore:**

Add a Loki datasource pointing at `http://loki-gateway.monitoring.svc.cluster.local`
if not already configured, then in Explore:

```
{namespace="taskly-staging"} | json
```

Every log line is structured JSON with a `trace_id`, so a single request's full log
trail can be found with:

```
{namespace="taskly-staging"} |= "<trace_id>"
```

**Alertmanager:**

```bash
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093
```

`http://localhost:9093`

## How to trigger an alert

The safest, most repeatable way to trigger `TasklyAPIDown` end-to-end (app →
Prometheus → Alertmanager → Slack) without bypassing GitOps:

1. In `helm/values-staging.yaml`, temporarily set `replicaCount: 0`.
2. Commit and push; let ArgoCD sync.
3. Wait ~1–2 minutes. Check `http://localhost:9090/alerts` — `TasklyAPIDown` should
   move from inactive → pending → firing, and a message should land in the configured
   Slack channel.
4. Revert `replicaCount` to its original value, commit, push, and let ArgoCD sync back.

## Alert rules

Three alerts are defined per environment in `monitoring/prometheus-rules*.yaml`:

| Alert | Condition | For |
|---|---|---|
| `TasklyHighErrorRate` | 5xx rate > 5% | 2m |
| `TasklyHighLatency` | p95 latency > 1s | 5m |
| `TasklyAPIDown` | No successful scrape of the API | 1m |

See `docs/runbook.md` for the incident response procedure when
`TasklyHighErrorRate` fires.

## Local development

```bash
cd taskly
docker compose up --build
```

Runs the API against local Postgres and Redis containers. See `taskly/README.md` for
details on environment variables and endpoints.