# =====================================================================
# Lambda execution role
# =====================================================================
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_s3_access" {
  statement {
    sid       = "ReadInputBucket"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.input.arn}/*"]
  }
  statement {
    sid       = "WriteOutputBucket"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.output.arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name   = "${local.name_prefix}-lambda-s3-access"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_s3_access.json
}

# =====================================================================
# Glue job role
# =====================================================================
data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_job" {
  name               = "${local.name_prefix}-glue-job"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue_s3_access" {
  statement {
    sid = "ReadCleanedOutput"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.output.arn,
      "${aws_s3_bucket.output.arn}/*",
    ]
  }
  statement {
    sid = "WriteParquetAndAssets"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject",
    ]
    resources = [
      aws_s3_bucket.parquet.arn,
      "${aws_s3_bucket.parquet.arn}/*",
      aws_s3_bucket.glue_assets.arn,
      "${aws_s3_bucket.glue_assets.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name   = "${local.name_prefix}-glue-s3-access"
  role   = aws_iam_role.glue_job.id
  policy = data.aws_iam_policy_document.glue_s3_access.json
}

# =====================================================================
# Redshift cluster role (allows COPY from S3, e.g. the Parquet bucket)
# =====================================================================
data "aws_iam_policy_document" "redshift_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["redshift.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redshift_copy" {
  name               = "${local.name_prefix}-redshift-copy"
  assume_role_policy = data.aws_iam_policy_document.redshift_assume.json
}

data "aws_iam_policy_document" "redshift_s3_read" {
  statement {
    sid = "ReadParquetForCopy"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.parquet.arn,
      "${aws_s3_bucket.parquet.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "redshift_s3_read" {
  name   = "${local.name_prefix}-redshift-s3-read"
  role   = aws_iam_role.redshift_copy.id
  policy = data.aws_iam_policy_document.redshift_s3_read.json
}
