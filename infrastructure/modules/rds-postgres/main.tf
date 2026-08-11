resource "aws_db_subnet_group" "taskly" {
  name = "taskly-db-subnet-group-${var.developer_name}-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "taskly-db-subnet-group-${var.developer_name}-${var.environment}"
  }
}

resource "aws_security_group" "rds" {
    name = "taskly-rds-sg-${var.developer_name}-${var.environment}"
    description = "Allo Postgres access from EKS nodes only"
    vpc_id = var.vpc_id

    ingress {
        description = "Postgres from EKS"
        from_port = var.postgres_port
        to_port = var.postgres_port
        protocol = "tcp"
        security_groups = [var.eks_node_security_group_id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags = {
        Name = "taskly-rds-sg-${var.developer_name}-${var.environment}"
    } 
}

resource "aws_db_instance" "taskly" {
  identifier = "taskly-${var.developer_name}-${var.environment}"
  engine = var.rds_engine
  engine_version = var.rds_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type = var.storage_type
  storage_encrypted = true

  db_name = var.db_name
  username = var.db_username
  manage_master_user_password = true # RDS generates & stores password in Secrets Manager

  db_subnet_group_name = aws_db_subnet_group.taskly.name
  vpc_security_group_ids = [ aws_security_group.rds.id ]

  multi_az = var.environment == "production" ? true : false
  publicly_accessible = false

  backup_retention_period = var.environment == "production" ? var.backup_retention_period_production : var.backup_retention_period_staging
  skip_final_snapshot = var.environment == "production" ? false : true
  deletion_protection = var.environment == "production" ? true : false

  tags = {
    Name = "taskly-${var.developer_name}-${var.environment}"
    Environment = var.environment
  }
}