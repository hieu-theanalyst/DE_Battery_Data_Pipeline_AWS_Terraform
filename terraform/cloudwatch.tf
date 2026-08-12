resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-pipeline-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

# ---------------------------------------------------------------------
# Lambda alarms
# ---------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Cleaning Lambda raised one or more errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.clean_transform.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.name_prefix}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.lambda_timeout * 1000 * 0.8 # alert at 80% of timeout
  alarm_description   = "Cleaning Lambda is approaching its configured timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.clean_transform.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---------------------------------------------------------------------
# Glue job failure alarm
# ---------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "glue_job_failures" {
  alarm_name          = "${local.name_prefix}-glue-job-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Glue ETL job had one or more failed tasks"
  treat_missing_data  = "notBreaching"

  dimensions = {
    JobName = aws_glue_job.clean_to_redshift.name
    JobRunId = "ALL"
    Type     = "count"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---------------------------------------------------------------------
# Log group for Glue job output (in addition to the Lambda log group in lambda.tf)
# ---------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "glue" {
  name              = "/aws-glue/jobs/${local.name_prefix}-csv-to-parquet-redshift"
  retention_in_days = 14
}
