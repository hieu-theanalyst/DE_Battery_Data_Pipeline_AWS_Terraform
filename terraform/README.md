# Terraform

Provisions the full pipeline: S3 (input/output/parquet/glue-assets), the
cleaning Lambda + S3 trigger, an RDS PostgreSQL instance (app metadata), a
Redshift cluster, the Glue connection + ETL job, IAM roles/policies, and
CloudWatch alarms/log groups.

## Prerequisites

1. **Build the Lambda zip first** — Terraform expects
   `../lambda/lambda_function.zip` to exist (see `lambda/README.md`).
2. **Set secrets via environment variables**, not tfvars:
   ```bash
   export TF_VAR_rds_master_password="..."
   export TF_VAR_redshift_master_password="..."
   ```
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and adjust bucket
   names / region / project name (bucket names must be globally unique).

## Apply

```bash
terraform init
terraform plan
terraform apply
```

## Design notes / simplifications (read before using beyond a demo)

- **Networking**: uses the account's **default VPC** by default
  (`use_default_vpc = true`) to keep the project self-contained. Set
  `use_default_vpc = false` and supply `vpc_id`/`subnet_ids` to use a
  purpose-built VPC instead.
- **Security groups** are scoped to the VPC CIDR, not to specific
  peers/IPs — fine for a demo, too broad for production. Tighten before
  using with real data.
- **RDS/Redshift** are not publicly accessible, have `skip_final_snapshot
  = true`, and minimal backup retention — intentional for a low-cost,
  disposable academic deployment. Increase backup retention and enable
  Multi-AZ for anything real.
- **Passwords**: RDS/Redshift master passwords are plain Terraform
  variables (marked `sensitive`) for simplicity. For real use, generate
  them with `random_password` and store in AWS Secrets Manager instead of
  passing through `TF_VAR_*`/state.
- **Glue job script** is uploaded via `aws_s3_object` from the local repo;
  re-running `terraform apply` after editing `glue/glue_etl_job.py` will
  pick up the change (the `etag` forces a diff).
- **Cost**: this provisions billable resources (RDS, Redshift, NAT/Glue
  DPUs). Remember to `terraform destroy` when you're done experimenting.

## File map

| File              | Contents                                          |
|-------------------|----------------------------------------------------|
| `providers.tf`    | Terraform/provider version pins                    |
| `variables.tf`    | All input variables                                 |
| `main.tf`         | Locals, default-VPC lookups                        |
| `s3.tf`           | Input/output/parquet/glue-assets buckets + trigger  |
| `iam.tf`          | Lambda, Glue, and Redshift IAM roles/policies       |
| `lambda.tf`       | Lambda function, log group, S3 invoke permission    |
| `glue.tf`         | Glue connection, ETL job, optional schedule trigger |
| `rds.tf`          | RDS PostgreSQL (app metadata / OLTP)                |
| `redshift.tf`     | Redshift cluster (analytics / OLAP)                 |
| `cloudwatch.tf`   | SNS topic + alarms for Lambda/Glue failures         |
| `outputs.tf`      | Resource names/endpoints for downstream use          |
