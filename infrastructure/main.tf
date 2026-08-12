locals {
  cluster_name = "platform-eks-${var.developer_name}"
  vpc_name     = "platform-vpc-${var.developer_name}"
}

data "aws_route53_zone" "platform_hosted_zone" {
  name = "ironlabs.online"
}

# -------- Set k8s provider ----------
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", "us-east-1"
    ]
  }

}

# --- Network ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.vpc_name
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # ONE NAT gateway, not one per AZ (each costs ~$32/mo)
  enable_dns_hostnames = true

  # Tags that let EKS find subnets for load balancers
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

}

# --- EKS cluster + worker nodes ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true # you get kubectl admin automatically

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = [var.instance_type]
      min_size       = var.min_nodes
      max_size       = var.max_nodes
      desired_size   = var.desired_nodes
    }
  }
}

# ------ RDS --------
module "rds" {
  source = "./modules/rds-postgres"

  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnets
  eks_node_security_group_id = module.eks.node_security_group_id
  db_instance_class          = var.db_instance_class
  db_username                = "taskly_${var.developer_name}"
  db_name                    = var.db_name
  developer_name             = var.developer_name
}

# ------- Redis ----------
module "redis" {
  source = "./modules/elasticache-redis"

  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnets
  eks_node_security_group_id = module.eks.node_security_group_id
  node_type                  = var.node_type
  developer_name             = var.developer_name
}

# ------ k8s secrets ------
resource "kubernetes_secret_v1" "taskly_db" {
  metadata {
    name = "taskly-db-credentials"
  }

  data = {
    DB_HOST       = module.rds.endpoint
    DB_PORT       = tostring(module.rds.port)
    DB_NAME       = module.rds.database_name
    REDIS_HOST    = module.redis.endpoint
    REDIS_PORT    = tostring(module.redis.port)
    DB_SECRET_ARN = module.rds.master_user_secret_arn # the pod uses it later to retrieve the db password from the secret manager
  }

  type = "Opaque"
}

# --------- IRSA ------------
data "aws_iam_policy_document" "taskly_secrets_access" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.rds.master_user_secret_arn]
  }
}

resource "aws_iam_policy" "taskly_secrets_access" {
  name   = "platform-${var.developer_name}-secrets-access"
  policy = data.aws_iam_policy_document.taskly_secrets_access.json
}

module "taskly_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "platform-${var.developer_name}-app-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:platform-app"] # namespace:service-account-name
    }
  }

  role_policy_arns = {
    secrets_access = aws_iam_policy.taskly_secrets_access.arn
  }
}

resource "kubernetes_service_account_v1" "taskly_app" {
  metadata {
    name      = "platform-app"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.taskly_irsa.iam_role_arn
    }
  }
}

# ------------- External DNS IRSA -----------------
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
  name   = "platform-${var.developer_name}-external-dns"
  policy = data.aws_iam_policy_document.external_dns.json
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "platform-${var.developer_name}-external-dns-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  role_policy_arns = {
    external_dns = aws_iam_policy.external_dns.arn
  }
}