output "input_bucket_name" {
  value = aws_s3_bucket.input.bucket
}

output "output_bucket_name" {
  value = aws_s3_bucket.output.bucket
}

output "parquet_bucket_name" {
  value = aws_s3_bucket.parquet.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.clean_transform.function_name
}

output "glue_job_name" {
  value = aws_glue_job.clean_to_redshift.name
}

output "rds_endpoint" {
  value     = aws_db_instance.app.endpoint
  sensitive = true
}

output "redshift_endpoint" {
  value     = aws_redshift_cluster.analytics.endpoint
  sensitive = true
}

output "sns_alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
