variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "developer_name" {
  type = string
}

variable "redis_port" {
  type = number
  default = 6379
}

variable "elasticache_engine" {
  type = string
  default = "redis"
}

variable "elasticache_engine_version" {
  type = string
  default = "7.1"
}

variable "num_cache_nodes" {
  type = number
  default = 1
}

variable "parameter_group_name" {
  type = string
  default = "default.redis7"
}