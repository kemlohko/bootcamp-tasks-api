locals {
  cluster_name = "eks-taskly-${var.developer_name}-${var.environment}"
  vpc_name     = "vpc-taskly-${var.developer_name}-${var.environment}"
}

# --- Network ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.vpc_name
  cidr = "20.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["20.0.1.0/24", "20.0.2.0/24"]
  public_subnets  = ["20.0.101.0/24", "20.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true   # ONE NAT gateway, not one per AZ (each costs ~$32/mo)
  enable_dns_hostnames = true

  # Tags that let EKS find subnets for load balancers
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  tags = {
    Environment = var.environment
  }
}

# --- EKS cluster + worker nodes ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true   # you get kubectl admin automatically

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

  tags = {
    Environment = var.environment
  }
}

# ------ RDS --------
module "rds" {
  source = "../../modules/rds-postgres"

  environment = var.environment
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  eks_node_security_group_id = module.eks.node_security_group_id
  db_instance_class = var.db_instance_class
  db_username = "taskly_${var.developer_name}_${var.environment}"
  db_name = var.db_name
  developer_name = var.developer_name
}

# ------- Redis ----------
module "redis" {
  source = "../../modules/elasticache-redis"

  environment = var.environment
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  eks_node_security_group_id = module.eks.node_security_group_id
  node_type = var.node_type
  developer_name = var.developer_name
}