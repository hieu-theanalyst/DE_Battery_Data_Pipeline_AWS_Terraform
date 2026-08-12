resource "aws_redshift_subnet_group" "analytics" {
  name       = "${local.name_prefix}-redshift-subnets"
  subnet_ids = local.subnet_ids
}

resource "aws_security_group" "redshift" {
  name        = "${local.name_prefix}-redshift-sg"
  description = "Allow Redshift access to the analytics cluster"
  vpc_id      = local.vpc_id

  ingress {
    description = "Redshift from within the VPC (tighten to your BI tool's egress IPs in real use)"
    from_port   = 5439
    to_port     = 5439
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

resource "aws_redshift_cluster" "analytics" {
  cluster_identifier = "${local.name_prefix}-redshift"
  node_type          = var.redshift_node_type
  cluster_type       = var.redshift_cluster_type
  number_of_nodes    = var.redshift_cluster_type == "multi-node" ? var.redshift_number_of_nodes : null

  database_name   = var.redshift_db_name
  master_username = var.redshift_master_username
  master_password = var.redshift_master_password

  cluster_subnet_group_name = aws_redshift_subnet_group.analytics.name
  vpc_security_group_ids    = [aws_security_group.redshift.id]
  iam_roles                 = [aws_iam_role.redshift_copy.arn]

  # Demo-friendly defaults -- revisit for anything beyond a portfolio project.
  publicly_accessible = false
  skip_final_snapshot = true
  encrypted           = true

  tags = {
    Name = "${local.name_prefix}-redshift"
  }
}
