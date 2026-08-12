variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag resources"
  type        = string
  default     = "battery-data-pipeline"
}

variable "environment" {
  description = "Environment name (e.g. dev, academic)"
  type        = string
  default     = "dev"
}

# ---------------------------------------------------------------------
# Networking (uses the account's default VPC for simplicity -- this is
# an academic/portfolio project, not a production network design. Swap
# these for a purpose-built VPC + private subnets before real use.)
# ---------------------------------------------------------------------

variable "use_default_vpc" {
  description = "If true, look up and use the account's default VPC/subnets"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID to deploy RDS/Redshift/Glue connection into (ignored if use_default_vpc is true)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for RDS/Redshift subnet groups (ignored if use_default_vpc is true)"
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------
# S3
# ---------------------------------------------------------------------

variable "input_bucket_name" {
  description = "S3 bucket battery-test files are uploaded/exported to"
  type        = string
  default     = "battery-data-input"
}

variable "output_bucket_name" {
  description = "S3 bucket the cleaning Lambda writes cleaned CSVs to"
  type        = string
  default     = "battery-data-output"
}

variable "parquet_bucket_name" {
  description = "S3 bucket the Glue job writes partitioned Parquet to"
  type        = string
  default     = "battery-data-parquet"
}

variable "glue_assets_bucket_name" {
  description = "S3 bucket holding Glue job scripts and temp/staging data"
  type        = string
  default     = "battery-data-glue-assets"
}

# ---------------------------------------------------------------------
# Lambda
# ---------------------------------------------------------------------

variable "lambda_zip_path" {
  description = "Path to the built Lambda deployment package (see lambda/README.md)"
  type        = string
  default     = "../lambda/lambda_function.zip"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_mb" {
  description = "Lambda memory in MB"
  type        = number
  default     = 512
}

# ---------------------------------------------------------------------
# RDS (PostgreSQL, OLTP / app metadata)
# ---------------------------------------------------------------------

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.4"
}

variable "rds_allocated_storage_gb" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_db_name" {
  description = "Initial database name"
  type        = string
  default     = "battery_app"
}

variable "rds_master_username" {
  description = "RDS master username"
  type        = string
  default     = "app_admin"
}

variable "rds_master_password" {
  description = "RDS master password. Provide via TF_VAR_rds_master_password env var or a secrets manager -- never commit a real value."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------
# Redshift (OLAP)
# ---------------------------------------------------------------------

variable "redshift_node_type" {
  description = "Redshift node type"
  type        = string
  default     = "dc2.large"
}

variable "redshift_cluster_type" {
  description = "single-node or multi-node"
  type        = string
  default     = "single-node"
}

variable "redshift_number_of_nodes" {
  description = "Number of nodes (only used when cluster_type is multi-node)"
  type        = number
  default     = 1
}

variable "redshift_db_name" {
  description = "Redshift database name"
  type        = string
  default     = "battery_analytics"
}

variable "redshift_master_username" {
  description = "Redshift master username"
  type        = string
  default     = "analytics_admin"
}

variable "redshift_master_password" {
  description = "Redshift master password. Provide via TF_VAR_redshift_master_password env var or a secrets manager -- never commit a real value."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------
# CloudWatch
# ---------------------------------------------------------------------

variable "alarm_notification_email" {
  description = "Email address to notify on Lambda/Glue failure alarms (subscribed to an SNS topic)"
  type        = string
  default     = ""
}
