"""
Battery test data cleaning Lambda.

Triggered by an S3 ObjectCreated event on the input bucket. Downloads the
raw battery-cycler CSV export, parses the cycler's "Xd HH:MM:SS.ss" time
format into numeric seconds/hours columns, drops unused/empty columns, and
writes the cleaned CSV to the output bucket.

Environment variables:
    OUTPUT_BUCKET   - S3 bucket to write cleaned files to (required)
"""

import io
import os
import re

import boto3
import pandas as pd

s3 = boto3.client("s3")

OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET", "battery-data-output")

TIME_PATTERN = re.compile(r"(\d+)d\s+(\d+):(\d+):([\d.]+)")


def convert_to_seconds(time_str):
    """Parse 'Xd HH:MM:SS.ss' format into total seconds.

    Returns 0.0 for missing/unparseable values rather than raising, since a
    handful of malformed rows shouldn't fail the whole file.
    """
    if pd.isna(time_str) or not isinstance(time_str, str):
        return 0.0

    match = TIME_PATTERN.search(time_str.strip())
    if not match:
        return 0.0

    days, hours, minutes, seconds = match.groups()
    return (
        int(days) * 86400
        + int(hours) * 3600
        + int(minutes) * 60
        + float(seconds)
    )


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Apply the cleaning/transform rules to a raw cycler-export dataframe."""

    # Drop known-unwanted column and any fully-empty columns.
    df = df.drop(columns=["DPT Time"], errors="ignore").dropna(axis=1, how="all")

    if "Test Time" not in df.columns or "Step Time" not in df.columns:
        raise ValueError(
            "Expected 'Test Time' and 'Step Time' columns not found in input file"
        )

    test_seconds = df["Test Time"].apply(convert_to_seconds)
    step_seconds = df["Step Time"].apply(convert_to_seconds)

    insert_pos = df.columns.get_loc("Test Time")
    df = df.drop(columns=["Test Time", "Step Time"])

    df.insert(insert_pos, "Test Time (s)", test_seconds)
    df.insert(insert_pos + 1, "Test Time (h)", test_seconds / 3600)
    df.insert(insert_pos + 2, "Step Time (s)", step_seconds)
    df.insert(insert_pos + 3, "Step Time (h)", step_seconds / 3600)

    return df


def lambda_handler(event, context):
    record = event["Records"][0]["s3"]
    input_bucket = record["bucket"]["name"]
    file_key = record["object"]["key"]

    try:
        response = s3.get_object(Bucket=input_bucket, Key=file_key)
        content = response["Body"].read()

        # skiprows=1 handles the cycler export's leading title/metadata row.
        df = pd.read_csv(io.BytesIO(content), skiprows=1)
        df = clean_dataframe(df)

        csv_buffer = io.StringIO()
        df.to_csv(csv_buffer, index=False)

        output_key = f"cleaned_{os.path.basename(file_key)}"
        if not output_key.endswith(".csv"):
            output_key += ".csv"

        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=output_key,
            Body=csv_buffer.getvalue(),
        )

        return {
            "statusCode": 200,
            "body": f"Successfully processed {file_key} and uploaded to {output_key}",
        }

    except Exception as exc:  # noqa: BLE001 - re-raised for Lambda error reporting
        print(f"Error processing {file_key} from {input_bucket}: {exc}")
        raise
