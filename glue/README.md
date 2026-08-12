# Glue ETL Job

`glue_etl_job.py` is a Glue 4.0 (Spark) job that:

1. Reads the Lambda-cleaned CSVs from the output bucket.
2. Casts columns to their analytics types and adds a `load_date` partition
   column.
3. Writes partitioned Parquet back to S3 (the "Parquet" stage shown in the
   architecture diagram).
4. Loads the same data into Redshift over a Glue JDBC connection.

## Column assumptions

The job assumes the cleaned CSV has: `Cycle`, `Step`, `Test Time (s)`,
`Test Time (h)`, `Step Time (s)`, `Step Time (h)`, `Voltage`, `Current`,
`Capacity`, `Energy`. This matches a typical battery-cycler export plus the
time columns the Lambda derives. **If your actual cycler export has
different column names, update the `withColumn`/`select` list and the
`ApplyMapping` calls accordingly** — this is the one place in the repo
where the schema is hardcoded on purpose (Glue's schema inference isn't
reliable enough to leave fully dynamic for a Redshift load).

## Deploying

`terraform/glue.tf` creates the Glue job resource and expects the script at
`s3://<glue-assets-bucket>/scripts/glue_etl_job.py` — upload it there (or
add a `null_resource`/CI step to sync it) before running the job. The
Terraform also wires up the job arguments listed at the top of the script.

## Redshift connection

The Glue job uses a **Glue Connection** (`REDSHIFT_CONNECTION` arg) rather
than hardcoded JDBC credentials, so Redshift username/password stay in
Secrets Manager / the Glue connection object, not in code or Terraform
state in plaintext. See `terraform/redshift.tf` and `terraform/glue.tf`.
