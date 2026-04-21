data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "random_password" "db_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 24
  special = true
}

locals {
  master_password = var.db_password != "" ? var.db_password : random_password.db_password[0].result
}

resource "aws_security_group" "rds_mysql_access" {
  name        = "${var.project_name}-rds-mysql-access"
  description = "Allow remote MySQL access to RDS."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "MySQL from allowed CIDR"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-mysql-access"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = data.aws_subnets.default_vpc_subnets.ids

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-mysql"
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.allocated_storage + 100
  storage_type           = "gp3"
  engine                 = "mysql"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = local.master_password
  port                   = 3306
  publicly_accessible    = var.publicly_accessible
  vpc_security_group_ids = [aws_security_group.rds_mysql_access.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  backup_retention_period = 7
  deletion_protection    = false
  skip_final_snapshot    = var.skip_final_snapshot
  apply_immediately      = true

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
