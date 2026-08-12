resource "aws_security_group" "glue_connection" {
  name        = "${local.name_prefix}-glue-sg"
  description = "SG used by the Glue connection to reach Redshift"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Glue requires a self-referencing ingress rule for its connection ENIs.
  ingress {
    description = "Self-referencing rule required by Glue connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
}

resource "aws_glue_connection" "redshift" {
  name = "${local.name_prefix}-redshift-connection"

  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${aws_redshift_cluster.analytics.endpoint}/${var.redshift_db_name}"
    USERNAME             = var.redshift_master_username
    PASSWORD             = var.redshift_master_password
  }

  physical_connection_requirements {
    availability_zone      = aws_redshift_cluster.analytics.availability_zone
    security_group_id_list = [aws_security_group.glue_connection.id]
    subnet_id               = local.subnet_ids[0]
  }
}

resource "aws_glue_job" "clean_to_redshift" {
  name         = "${local.name_prefix}-csv-to-parquet-redshift"
  role_arn     = aws_iam_role.glue_job.arn
  glue_version = "4.0"
  max_capacity = 2.0
  timeout      = 30

  connections = [aws_glue_connection.redshift.name]

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_assets.bucket}/scripts/glue_etl_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"        = "python"
    "--SOURCE_BUCKET"        = aws_s3_bucket.output.bucket
    "--SOURCE_PREFIX"        = ""
    "--PARQUET_BUCKET"       = aws_s3_bucket.parquet.bucket
    "--PARQUET_PREFIX"       = "battery_test_data/"
    "--REDSHIFT_CONNECTION"  = aws_glue_connection.redshift.name
    "--REDSHIFT_TABLE"       = "public.battery_test_data"
    "--REDSHIFT_TMP_DIR"     = "s3://${aws_s3_bucket.glue_assets.bucket}/redshift-tmp/"
    "--TempDir"              = "s3://${aws_s3_bucket.glue_assets.bucket}/glue-tmp/"
    "--enable-metrics"       = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }

  depends_on = [aws_s3_object.glue_job_script]
}

# Optional: trigger the Glue job on a schedule (e.g. hourly) rather than
# manually. Comment out if you'd rather kick it off from an S3 event /
# Step Functions / manually for a demo.
resource "aws_glue_trigger" "scheduled" {
  name     = "${local.name_prefix}-glue-hourly"
  type     = "SCHEDULED"
  schedule = "cron(0 * * * ? *)"

  actions {
    job_name = aws_glue_job.clean_to_redshift.name
  }

  enabled = false # off by default for a portfolio/demo project -- flip to true to enable
}
