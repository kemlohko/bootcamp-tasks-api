resource "aws_db_subnet_group" "platform-rds-sub-net" {
  name = "platform-${var.developer_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "platform-${var.developer_name}-db-subnet-group"
  }
}

resource "aws_security_group" "platform-rds-sg" {
    name = "platform-${var.developer_name}-rds-sg"
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
        Name = "platform-${var.developer_name}-rds-sg"
    } 
}

resource "aws_db_instance" "platform-rds" {
  identifier = "platform-${var.developer_name}-rds"
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

  db_subnet_group_name = aws_db_subnet_group.platform-rds-sub-net.name
  vpc_security_group_ids = [ aws_security_group.platform-rds-sg.id ]

  multi_az = true
  publicly_accessible = false

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "platform-${var.developer_name}-rds"
  }
}