# Incident Runbook: Taskly API Error Rate > 5%

This runbook covers the response procedure when the `TasklyHighErrorRate` alert fires
(error rate above 5% for more than 2 minutes) in either `taskly-staging` or
`taskly-production`.

## 1. Acknowledge

- Alert arrives in `#taskly-alerts` on Slack, sourced from Alertmanager.
- Note the `namespace` label on the alert — confirm whether this is staging or
  production before doing anything else. Production incidents take priority.

## 2. Assess scope

Open the Grafana dashboard (**Taskly API**, namespace selector set to the affected
environment) and check, in order:

1. **Error Rate by Path** panel — is the error rate concentrated on one endpoint, or
   spread across all of them? A single-path spike usually points to a code or data
   issue; an across-the-board spike usually points to an infrastructure issue
   (database, cache, or network).
2. **Requests by Path & Status** panel — confirm the actual status codes involved.
   5xx only, or mixed with an unusual volume of 4xx?
3. **Request Rate** panel — has traffic volume itself changed? A sudden traffic spike
   can produce errors that aren't really "broken," just under-provisioned.

## 3. Find the failing requests

Every request is logged as structured JSON with a `trace_id`. Use Grafana Explore
(Loki datasource) to find recent errors:

```
{namespace="taskly-staging"} | json | level="ERROR"
```

Each `ERROR`-level line was logged from `db.connect()`, `db.ping()`, or an unhandled
exception in a route, and includes the underlying error message. Copy a `trace_id`
from an affected request and pull its full trail:

```
{namespace="taskly-staging"} |= "<trace_id>"
```

## 4. Common causes and checks

| Symptom in logs | Likely cause | Check |
|---|---|---|
| `Database connection failed` | RDS unreachable, wrong credentials, or connection pool exhausted | `kubectl get pods -n taskly-staging` — are pods crash-looping? `kubectl logs` on a pod for the exact `asyncpg` error. |
| `Redis connection failed` / cache timeouts | ElastiCache unreachable | `kubectl exec` into a pod and test `redis-cli -h <REDIS_HOST> ping`. |
| 503 on `/health` specifically | `db.ping()` failing | Check RDS instance status in the AWS console; check security group rules haven't drifted. |
| Errors concentrated on one path only | Application bug in that route | Check recent commits to `main` around the time the alert fired; consider rollback (see `rollback.md`). |
| Sudden error spike right after a deploy | Bad release | Roll back immediately — see `rollback.md`. |

## 5. Mitigate

- **If tied to a recent deploy:** roll back immediately using the procedure in
  `docs/rollback.md`. Don't spend time root-causing a bad deploy in production while
  it's actively serving errors — roll back first, investigate after.
- **If tied to infrastructure (RDS/Redis unreachable):** check the AWS console for the
  resource's status. If it's an AZ-level or transient AWS issue, monitor; if it's a
  configuration drift (security group, subnet), fix via Terraform and re-apply.
- **If tied to load:** check whether the HPA is scaling as expected
  (`kubectl get hpa -n taskly-staging`). If `metrics-server` is unhealthy, the HPA
  can't react — see `kubectl top nodes` to confirm metrics are flowing.

## 6. Confirm resolution

- Watch the **Error Rate** panel return below 5% and stay there.
- Confirm the alert clears in Alertmanager (`http://localhost:9093` via port-forward)
  and a "resolved" notification appears in Slack.

## 7. Write it up

For anything beyond a transient blip, note in the team channel (or, for this project,
in a short postmortem note): what triggered it, what the fix was, and whether a
follow-up change (code fix, alert threshold tuning, capacity change) is needed.
