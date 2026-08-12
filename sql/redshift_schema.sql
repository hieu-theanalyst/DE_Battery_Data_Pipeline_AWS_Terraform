-- =====================================================================
-- Redshift: analytics (OLAP) schema
-- Target table for the Glue ETL job (glue/glue_etl_job.py). Columns match
-- a typical battery-cycler export plus the derived time columns produced
-- by the cleaning Lambda. Adjust to your real column set if different.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.battery_test_data (
    cycle        INTEGER,
    step         INTEGER,
    test_time_s  DOUBLE PRECISION,
    test_time_h  DOUBLE PRECISION,
    step_time_s  DOUBLE PRECISION,
    step_time_h  DOUBLE PRECISION,
    voltage      DOUBLE PRECISION,
    current      DOUBLE PRECISION,
    capacity     DOUBLE PRECISION,
    energy       DOUBLE PRECISION,
    load_date    DATE
)
DISTSTYLE KEY
DISTKEY (cycle)
SORTKEY (load_date, cycle, step);

-- =====================================================================
-- Alternative bulk-load path: COPY straight from the Parquet output
-- bucket, if you'd rather load directly than go through the Glue job's
-- JDBC write. Requires the Redshift cluster's IAM role to have read
-- access to the Parquet bucket (see terraform/iam.tf).
-- =====================================================================

-- COPY public.battery_test_data
-- FROM 's3://battery-data-parquet/battery_test_data/'
-- IAM_ROLE 'arn:aws:iam::<account-id>:role/redshift-copy-role'
-- FORMAT AS PARQUET;
