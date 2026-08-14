output "cluster_name" {
  value = data.terraform_remote_state.platform.outputs.cluster_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "redis_endpoint" {
  value = module.redis.endpoint
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_taskly.arn
}

output "external_dns_role_arn" {
  value = module.external_dns_irsa.iam_role_arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.taskly.repository_url
}