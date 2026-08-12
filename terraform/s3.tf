# ---------------------------------------------------------------------
# Input bucket: raw battery-cycler exports land here (directly, or via
# an RDS-backed upload app's export step).
# ---------------------------------------------------------------------
resource "aws_s3_bucket" "input" {
  bucket = var.input_bucket_name
}

resource "aws_s3_bucket_versioning" "input" {
  bucket = aws_s3_bucket.input.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "input" {
  bucket                  = aws_s3_bucket.input.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input" {
  bucket = aws_s3_bucket.input.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------
# Output bucket: cleaning Lambda writes cleaned CSVs here. Also the
# event source for downstream Glue processing.
# ---------------------------------------------------------------------
resource "aws_s3_bucket" "output" {
  bucket = var.output_bucket_name
}

resource "aws_s3_bucket_public_access_block" "output" {
  bucket                  = aws_s3_bucket.output.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output" {
  bucket = aws_s3_bucket.output.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------
# Parquet bucket: Glue job's converted, partitioned output.
# ---------------------------------------------------------------------
resource "aws_s3_bucket" "parquet" {
  bucket = var.parquet_bucket_name
}

resource "aws_s3_bucket_public_access_block" "parquet" {
  bucket                  = aws_s3_bucket.parquet.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------
# Glue assets bucket: job script + Redshift JDBC staging/tmp dir.
# ---------------------------------------------------------------------
resource "aws_s3_bucket" "glue_assets" {
  bucket = var.glue_assets_bucket_name
}

resource "aws_s3_bucket_public_access_block" "glue_assets" {
  bucket                  = aws_s3_bucket.glue_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "glue_job_script" {
  bucket = aws_s3_bucket.glue_assets.id
  key    = "scripts/glue_etl_job.py"
  source = "../glue/glue_etl_job.py"
  etag   = filemd5("../glue/glue_etl_job.py")
}

# ---------------------------------------------------------------------
# S3 -> Lambda trigger
# ---------------------------------------------------------------------
resource "aws_s3_bucket_notification" "input_triggers_lambda" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.clean_transform.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
