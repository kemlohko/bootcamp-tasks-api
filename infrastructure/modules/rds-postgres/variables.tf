variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type = string
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type = string
}

variable "developer_name" {
  type = string
}

variable "postgres_port" {
  type = number
  default = 5432
}

variable "allocated_storage" {
  type = number
  default = 20
}

variable "max_allocated_storage" {
  type = number
  default = 100
}

variable "storage_type" {
  type = string
  default = "gp3"
}

variable "backup_retention_period" {
  type = number
  default = 7
}

variable "rds_engine" {
  type = string
  default = "postgres"
}

variable "rds_engine_version" {
  type = string
  default = "15.8"
}