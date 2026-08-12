resource "aws_elasticache_subnet_group" "platform-sub-net" {
  name = "platform-${var.developer_name}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "platform-redis-sg" {
  name = "platform-${var.developer_name}-redis-sg"
  description = "Allow Redis access from EKS node only"
  vpc_id = var.vpc_id

  ingress {
    description = "Redis from EKS"
    from_port = var.redis_port
    to_port = var.redis_port
    protocol = "tcp"
    security_groups = [ var.eks_node_security_group_id ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    Name = "platform-${var.developer_name}-redis-sg"
  }
}

resource "aws_elasticache_cluster" "platform-redis" {
  cluster_id = "platform-${var.developer_name}"
  engine = var.elasticache_engine
  engine_version = var.elasticache_engine_version
  node_type = var.node_type
  num_cache_nodes = var.num_cache_nodes
  port = var.redis_port
  parameter_group_name = var.parameter_group_name

  subnet_group_name = aws_elasticache_subnet_group.platform-sub-net.name
  security_group_ids = [ aws_security_group.platform-redis-sg.id ]

  tags = {
    Name = "platform-${var.developer_name}-redis"
  }
}