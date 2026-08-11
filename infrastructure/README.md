# Turn EKS on and off super quickly with the following scripts.

You just need a working AWS account (with your AWS CLI already set up).

1. Turn on the cluster (staging defaults to 2 t3.medium nodes; see `infrastructure/environments/<env>/main.tf` for exact sizing):

```bash
cd infrastructure
chmod +x up.sh down.sh
./up.sh <your-name> <environment>
```

Example:
```bash
./up.sh richard staging
```

Valid environments: `staging`, `production`

2. When you're done, turn it off — **always use the same `<your-name>` and `<environment>` you used to bring it up**, or Terraform won't be able to find/target the right resources:

```bash
./down.sh <your-name> <environment>
```

Example:
```bash
./down.sh richard staging
```

⚠️ **Don't forget to run `down.sh`** — an idle EKS cluster + RDS + ElastiCache still bills continuously even with zero traffic.