resource "aws_db_subnet_group" "app" {
  name       = "${local.name_prefix}-rds-subnets"
  subnet_ids = local.subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow PostgreSQL access to the app RDS instance"
  vpc_id      = local.vpc_id

  ingress {
    description = "PostgreSQL from within the VPC (tighten to your app's SG in real use)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default[0].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "app" {
  identifier     = "${local.name_prefix}-rds"
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage_gb
  storage_encrypted     = true
  db_name               = var.rds_db_name
  username               = var.rds_master_username
  password               = var.rds_master_password
  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Demo-friendly defaults -- revisit for anything beyond a portfolio project.
  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 1
  deletion_protection     = false

  tags = {
    Name = "${local.name_prefix}-rds"
  }
}
