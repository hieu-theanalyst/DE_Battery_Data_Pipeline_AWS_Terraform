# Design decisions

Notes on choices made while turning the original architecture sketch and
provided code into a working repo, so anyone (including future-you) can
see what was inferred vs. explicitly specified.

## CSV vs. Parquet at the "S3 Output Bucket" stage

The original diagram labels the S3 output bucket "Parquet", but the
provided Lambda code writes CSV. Resolved as: **Lambda keeps writing CSV
as-is; a separate Glue job converts CSV → Parquet** before loading
Redshift, writing the Parquet to its own bucket/prefix
(`battery-data-parquet`). This matches the diagram's implied "Glue does
the ETL job" role and keeps the Lambda simple and fast.

## Redshift/Glue schema for battery test data

The provided code and SQL only define the *time* columns (`Test Time`,
`Step Time`) and the RDS app-metadata schema — there's no schema for the
actual battery measurement columns. This repo assumes a **typical
battery-cycler export schema**: `Cycle`, `Step`, `Voltage`, `Current`,
`Capacity`, `Energy`, plus the Lambda-derived time columns. If your real
cycler export has different/additional columns (e.g. `Cycle Capacity`,
`Discharge Capacity`, `Temperature`), update:

- `glue/glue_etl_job.py` (the `withColumn`/`select`/`ApplyMapping` calls)
- `sql/redshift_schema.sql` (the `CREATE TABLE` statement)

## RDS's role / the web app

`admin_users`/`upload_users` back a web app that isn't part of this repo.
This repo includes the schema as-is (`sql/rds_app_schema.sql`) and treats
the app itself as out of scope, per project scope decision. The pipeline
still works standalone if files are dropped directly into the S3 input
bucket (the diagram's "Data → Extract → S3 Input Bucket" path).

## Resource naming

All AWS resource names in this repo (`battery-data-input`,
`battery-data-output`, etc.) are generic placeholders, not the real names
from the original Lambda code (`dataoutput-ct`). Swap them in
`terraform.tfvars` before deploying to your own account — S3 bucket names
must be globally unique, so the defaults will need to change regardless.

## Networking

Terraform defaults to the account's **default VPC** to keep the project
self-contained and easy to `apply` for a demo/academic environment. See
`terraform/README.md` for how to point it at a real VPC instead.
