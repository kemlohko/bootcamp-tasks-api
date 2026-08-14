output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "redis_endpoint" {
  value = module.redis.endpoint
}

output "connect_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "external_dns_role_arn" {
  value = module.external_dns_irsa.iam_role_arn
}

output "hosted_zone_id" {
  value = data.aws_route53_zone.platform_hosted_zone.zone_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}