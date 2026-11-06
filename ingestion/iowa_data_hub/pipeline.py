"""Iowa liquor products and sales (data.iowa.gov, CC BY 4.0) -> raw_iowa_data_hub.

Dataset ids and the yearly sales list: .dlt/config.toml next to this file. No
source credentials: the data is public. From the repo root:

    python -m ingestion.iowa_data_hub.pipeline
"""

import csv
import io
import itertools
import tempfile
import zipfile

import dlt
from dlt.sources.helpers import requests

from ingestion.setup import report, setup

# The catalog pages are a JS app with no static links; this is the real export.
DOWNLOAD_URL = "https://data.iowa.gov/api/dataset-download?path=datasets%2F{}%2Frows.csv"


def read_csv_zip(dataset_id):
    """Yield the rows of a dataset's zip export in pages. A big dataset is split into part_000N.csv files."""
    # On disk, not in memory: one year of sales is ~450 MB zipped.
    with tempfile.TemporaryFile() as f:
        with requests.get(DOWNLOAD_URL.format(dataset_id), stream=True, timeout=600) as r:
            r.raise_for_status()
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
        # A broken export comes back as a 0-byte zip: ZipFile raises BadZipFile, the run fails.
        with zipfile.ZipFile(f) as z:
            parts = sorted(n for n in z.namelist() if n.endswith(".csv"))
            if not parts:
                raise ValueError(f"dataset {dataset_id}: zip has no CSV")
            for part in parts:
                with z.open(part) as member:
                    rows = csv.DictReader(io.TextIOWrapper(member, encoding="utf-8-sig", newline=""))
                    # Every column lands as text, so codes keep leading zeros (vendor "035");
                    # staging casts. An empty cell is NULL.
                    for page in itertools.batched(rows, 10_000):
                        yield [{k: v or None for k, v in row.items()} for row in page]


@dlt.source(name="iowa_data_hub")
def iowa_data_hub(liquor_products_dataset=dlt.config.value, liquor_sales_datasets=dlt.config.value):
    # Monthly snapshot of the current catalog.
    @dlt.resource(write_disposition="replace")
    def liquor_products():
        yield from read_csv_zip(liquor_products_dataset)

    # One table per yearly dataset, liquor_sales_<year>, each replaced whole when it loads.
    # Past years are final: each loads once, then is left out of the run, so its table
    # is never touched. The latest year reloads every run.
    def sales_year(year, dataset_id, final):
        def rows():
            yield from read_csv_zip(dataset_id)
            if final:
                dlt.current.resource_state()["loaded"] = True

        return dlt.resource(rows, name=f"liquor_sales_{year}", write_disposition="replace")

    pipeline = dlt.current.pipeline()
    resources_state = dlt.current.source_state().get("resources", {})
    latest = max(liquor_sales_datasets)
    sales = [
        sales_year(year, dataset_id, final=year != latest)
        for year, dataset_id in sorted(liquor_sales_datasets.items())
        # On refresh, include every year: dlt then wipes each one's state and reloads it.
        if pipeline.refresh or not resources_state.get(f"liquor_sales_{year}", {}).get("loaded")
    ]
    return [liquor_products, *sales]


if __name__ == "__main__":
    setup(__file__)
    pipeline = dlt.pipeline(pipeline_name="iowa_data_hub", destination="postgres")
    # The source picks which years to load from the state, so restore it from the
    # warehouse first: a fresh CI runner has none, and run() restores it too late.
    pipeline.sync_destination()
    # csv loads with COPY: much faster than INSERT for ~35M sales rows.
    report(pipeline, pipeline.run(iowa_data_hub(), loader_file_format="csv"))
