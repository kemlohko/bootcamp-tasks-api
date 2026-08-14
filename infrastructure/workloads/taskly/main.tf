locals {
  namespaces = ["taskly-staging", "taskly-production"]
}

resource "kubernetes_namespace_v1" "taskly" {
  for_each = toset(local.namespaces)

  metadata {
    name = each.key
  }
}

# --- Data layer: one shared RDS + one shared Redis, per-env separation via table name ---

module "rds" {
  source = "../../modules/rds-postgres"

  vpc_id                      = data.terraform_remote_state.platform.outputs.vpc_id
  private_subnet_ids          = data.terraform_remote_state.platform.outputs.private_subnet_ids
  eks_node_security_group_id  = data.terraform_remote_state.platform.outputs.node_security_group_id
  db_instance_class            = "db.t3.micro"
  db_username                  = var.db_username
  developer_name = var.developer_name
  db_name = var.db_name
}

module "redis" {
  source = "../../modules/elasticache-redis"

  developer_name               = var.developer_name
  vpc_id                      = data.terraform_remote_state.platform.outputs.vpc_id
  private_subnet_ids          = data.terraform_remote_state.platform.outputs.private_subnet_ids
  eks_node_security_group_id  = data.terraform_remote_state.platform.outputs.node_security_group_id
  node_type                    = "cache.t3.micro"
}

# --- K8s Secret per namespace, pointing at the same shared RDS/Redis ---

resource "kubernetes_secret_v1" "taskly_db" {
  for_each = toset(local.namespaces)

  metadata {
    name      = "taskly-db-credentials"
    namespace = kubernetes_namespace_v1.taskly[each.key].metadata[0].name
  }

  data = {
    DB_HOST       = module.rds.endpoint
    DB_PORT       = tostring(module.rds.port)
    DB_NAME       = module.rds.database_name
    DB_USER       = var.db_username
    DB_SECRET_ARN = module.rds.master_user_secret_arn
    REDIS_URL     = "redis://${module.redis.endpoint}:${module.redis.port}"
  }

  type = "Opaque"
}

# --- IRSA: taskly-app ServiceAccount, trusted from both namespaces ---

module "taskly_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "taskly-${var.developer_name}-app-role"

  oidc_providers = {
    main = {
      provider_arn = data.terraform_remote_state.platform.outputs.oidc_provider_arn
      namespace_service_accounts = [
        "taskly-staging:taskly-app",
        "taskly-production:taskly-app",
      ]
    }
  }

  role_policy_arns = {
    secrets_access = aws_iam_policy.taskly_secrets_access.arn
  }
}

data "aws_iam_policy_document" "taskly_secrets_access" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.rds.master_user_secret_arn]
  }
}

resource "aws_iam_policy" "taskly_secrets_access" {
  name   = "taskly-${var.developer_name}-secrets-access"
  policy = data.aws_iam_policy_document.taskly_secrets_access.json
}

resource "kubernetes_service_account_v1" "taskly_app" {
  for_each = toset(local.namespaces)

  metadata {
    name      = "taskly-app"
    namespace = kubernetes_namespace_v1.taskly[each.key].metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.taskly_irsa.iam_role_arn
    }
  }
}

# --- ECR + GitHub Actions OIDC role (workload-scoped: this repo, this image) ---

resource "aws_ecr_repository" "taskly" {
  name                 = "alex/taskly"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.platform.outputs.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:kemlohko/bootcamp-tasks-api:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_taskly" {
  name               = "github-actions-role-${var.developer_name}"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.taskly.arn]
  }
}

resource "aws_iam_policy" "github_actions_permissions" {
  name   = "github-actions-taskly-permissions"
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

resource "aws_iam_role_policy_attachment" "github_actions_permissions" {
  role       = aws_iam_role.github_actions_taskly.name
  policy_arn = aws_iam_policy.github_actions_permissions.arn
}

# --- external-dns IRSA ---

data "aws_iam_policy_document" "external_dns" {
  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]
  }
  statement {
    effect    = "Allow"
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  name   = "taskly-${var.developer_name}-external-dns"
  policy = data.aws_iam_policy_document.external_dns.json
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "ExternalDNSRole-${data.terraform_remote_state.platform.outputs.cluster_name}"

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.platform.outputs.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  role_policy_arns = {
    external_dns = aws_iam_policy.external_dns.arn
  }
}