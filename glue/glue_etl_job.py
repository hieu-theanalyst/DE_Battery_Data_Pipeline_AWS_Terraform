"""
Glue ETL job: cleaned CSV (S3 output bucket) -> Parquet -> Redshift.

Run as a Glue 4.0 (Spark) job. Expects the following job arguments
(see terraform/glue.tf for how these are wired up):

    --SOURCE_BUCKET        S3 bucket containing Lambda-cleaned CSVs
    --SOURCE_PREFIX         Key prefix to read within SOURCE_BUCKET
    --PARQUET_BUCKET        S3 bucket to write partitioned Parquet output to
    --PARQUET_PREFIX        Key prefix to write Parquet under
    --REDSHIFT_CONNECTION   Name of the Glue connection to Redshift
    --REDSHIFT_TABLE        Target table, e.g. public.battery_test_data
    --REDSHIFT_TMP_DIR      S3 path Glue uses for staging during the JDBC load
"""

import sys
from datetime import date

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.transforms import ApplyMapping
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F

REQUIRED_ARGS = [
    "JOB_NAME",
    "SOURCE_BUCKET",
    "SOURCE_PREFIX",
    "PARQUET_BUCKET",
    "PARQUET_PREFIX",
    "REDSHIFT_CONNECTION",
    "REDSHIFT_TABLE",
    "REDSHIFT_TMP_DIR",
]

args = getResolvedOptions(sys.argv, REQUIRED_ARGS)

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

source_path = f"s3://{args['SOURCE_BUCKET']}/{args['SOURCE_PREFIX']}"
parquet_path = f"s3://{args['PARQUET_BUCKET']}/{args['PARQUET_PREFIX']}"

# 1. Read the Lambda-cleaned CSVs.
df = (
    spark.read.option("header", "true")
    .option("inferSchema", "true")
    .csv(source_path)
)

# 2. Light schema normalization / typing for the analytics table.
#    Column names here follow a typical battery-cycler export; adjust to
#    match your actual cleaned CSV columns.
typed_df = (
    df.withColumn("cycle", F.col("Cycle").cast("int"))
    .withColumn("step", F.col("Step").cast("int"))
    .withColumn("test_time_s", F.col("Test Time (s)").cast("double"))
    .withColumn("test_time_h", F.col("Test Time (h)").cast("double"))
    .withColumn("step_time_s", F.col("Step Time (s)").cast("double"))
    .withColumn("step_time_h", F.col("Step Time (h)").cast("double"))
    .withColumn("voltage", F.col("Voltage").cast("double"))
    .withColumn("current", F.col("Current").cast("double"))
    .withColumn("capacity", F.col("Capacity").cast("double"))
    .withColumn("energy", F.col("Energy").cast("double"))
    .withColumn("load_date", F.lit(date.today().isoformat()))
    .select(
        "cycle",
        "step",
        "test_time_s",
        "test_time_h",
        "step_time_s",
        "step_time_h",
        "voltage",
        "current",
        "capacity",
        "energy",
        "load_date",
    )
)

# 3. Write partitioned Parquet to the output bucket (this is the
#    "S3 Output Bucket / Parquet" stage in the architecture diagram).
(
    typed_df.write.mode("append")
    .partitionBy("load_date")
    .parquet(parquet_path)
)

# 4. Load into Redshift via the Glue JDBC connection.
dynamic_frame = glueContext.create_dynamic_frame.from_dataframe(
    typed_df, glueContext, "typed_df"
)
mapped_frame = ApplyMapping.apply(
    frame=dynamic_frame,
    mappings=[
        ("cycle", "int", "cycle", "int"),
        ("step", "int", "step", "int"),
        ("test_time_s", "double", "test_time_s", "double precision"),
        ("test_time_h", "double", "test_time_h", "double precision"),
        ("step_time_s", "double", "step_time_s", "double precision"),
        ("step_time_h", "double", "step_time_h", "double precision"),
        ("voltage", "double", "voltage", "double precision"),
        ("current", "double", "current", "double precision"),
        ("capacity", "double", "capacity", "double precision"),
        ("energy", "double", "energy", "double precision"),
        ("load_date", "string", "load_date", "date"),
    ],
)

glueContext.write_dynamic_frame.from_jdbc_conf(
    frame=mapped_frame,
    catalog_connection=args["REDSHIFT_CONNECTION"],
    connection_options={
        "dbtable": args["REDSHIFT_TABLE"],
        "database": "battery_analytics",
    },
    redshift_tmp_dir=args["REDSHIFT_TMP_DIR"],
)

job.commit()
