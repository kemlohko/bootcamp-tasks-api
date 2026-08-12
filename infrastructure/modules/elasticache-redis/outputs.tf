output "endpoint" {
  value = aws_elasticache_cluster.platform-redis.cache_nodes[0].address
}

output "port" {
  value = aws_elasticache_cluster.platform-redis.port
}