# Cleaning Lambda

`lambda_function.py` is triggered by an `s3:ObjectCreated:*` event on the
input bucket. It:

1. Downloads the raw CSV export.
2. Skips the cycler's leading title row (`skiprows=1`).
3. Drops the `DPT Time` column and any fully-empty columns.
4. Converts `Test Time` and `Step Time` from `Xd HH:MM:SS.ss` text into
   numeric `(s)` and `(h)` columns, inserted in place of the originals.
5. Writes `cleaned_<original_filename>.csv` to the output bucket
   (`OUTPUT_BUCKET` env var).

## Packaging for deployment

Pandas isn't in the default Lambda runtime, so it needs to ship in the
deployment package or as a layer. Simplest path for this project size:

```bash
cd lambda
pip install -r requirements.txt -t build/ --platform manylinux2014_x86_64 \
    --only-binary=:all: --python-version 3.12
cp lambda_function.py build/
cd build && zip -r ../lambda_function.zip . && cd ..
```

Terraform (`terraform/lambda.tf`) expects `lambda/lambda_function.zip` to
exist at `terraform apply` time — build it first, or wire the zip step into
CI before `terraform apply`.

For a more repeatable setup, consider AWS's official
[`awslambdaric`/pandas layer](https://docs.aws.amazon.com/lambda/latest/dg/python-layers.html)
or an AWS SAM/container-image build instead of the zip-based flow above.

## Local smoke test

```bash
pip install -r requirements.txt
python - <<'PY'
import pandas as pd
from lambda_function import clean_dataframe

df = pd.read_csv("../sample_data/sample_battery_test.csv", skiprows=1)
print(clean_dataframe(df).head())
PY
```

## Error handling notes

- Malformed time strings resolve to `0` seconds rather than failing the
  whole file (a handful of bad rows shouldn't block a batch).
- Missing `Test Time`/`Step Time` columns raise a `ValueError` so the
  Lambda fails loudly (and CloudWatch/the retry/DLQ config catches it)
  rather than silently writing a broken file.
