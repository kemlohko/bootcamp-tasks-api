output "endpoint" {
  value = aws_elasticache_cluster.taskly.cache_nodes[0].address
}

output "port" {
  value = aws_elasticache_cluster.taskly.port
}