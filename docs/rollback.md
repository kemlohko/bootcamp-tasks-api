# Rollback Runbook

Taskly is deployed via GitOps: ArgoCD continuously syncs the live cluster state to
match `helm/values-staging.yaml` / `helm/values-production.yaml` in this repository.
Because of that, **the correct rollback is a Git revert**, not a direct `kubectl` or
`argocd` command — anything applied outside Git will be reverted automatically by
ArgoCD's `selfHeal` the next time it syncs.

## Recommended method: Git revert (persists, matches source of truth)

1. Find the commit that introduced the bad deploy:

   ```bash
   git log --oneline -- helm/values-production.yaml
   ```

2. Revert it:

   ```bash
   git revert <bad-commit-sha> --no-edit
   git pull --rebase origin main
   git push
   ```

3. ArgoCD picks up the reverted `values-production.yaml` on its next poll (or force it
   immediately):

   ```bash
   argocd app sync taskly-production
   ```

4. Confirm the previous image tag is running again:

   ```bash
   kubectl get pods -n taskly-production -o jsonpath='{.items[*].spec.containers[*].image}'
   ```

This is the version to actually demo — it's the one that proves the GitOps promotion
model works in both directions.

## Emergency method: ArgoCD rollback (fast, temporary)

Use only when something is actively broken and a Git revert would take too long to
land. This does **not** persist — the next automated sync will revert it back to
whatever Git currently says, unless you also do a Git revert afterward.

```bash
argocd app history taskly-production
argocd app rollback taskly-production <revision-id>
```

## Emergency method: kubectl rollout undo (fastest, most temporary)

Bypasses ArgoCD entirely. Same caveat as above — ArgoCD's `selfHeal` will undo this
rollback on its next sync unless Git is also updated.

```bash
kubectl rollout history deployment/taskly-api -n taskly-production
kubectl rollout undo deployment/taskly-api -n taskly-production
```

## Which one to use

| Situation | Method |
|---|---|
| Demoing the rollback capability | Git revert |
| Production actively down, need it stopped *right now* | `kubectl rollout undo`, then follow up with a Git revert within minutes |
| Need to see what previous versions are available | `argocd app history` |

## After any rollback

- Confirm the fix in Grafana (error rate back to normal) and Slack (alert resolved).
- If the rollback was an emergency (kubectl/argocd only), make sure the Git revert
  still happens afterward — otherwise the next `deploy-production` pipeline run, or
  even just ArgoCD's routine self-heal sync, will silently redeploy the bad version.
