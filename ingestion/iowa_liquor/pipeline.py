"""Iowa liquor products and sales (data.iowa.gov, CC BY 4.0) -> raw_iowa_liquor.

Dataset ids and the yearly sales list: .dlt/config.toml next to this file. No
source credentials: the data is public. From the repo root:

    python -m ingestion.iowa_liquor.pipeline
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


@dlt.source(name="iowa_liquor")
def iowa_liquor(products_dataset=dlt.config.value, sales_datasets=dlt.config.value):
    # Monthly snapshot of the current catalog.
    @dlt.resource(write_disposition="replace")
    def products():
        yield from read_csv_zip(products_dataset)

    # One dataset per year. Past years are final, so each loads once; the latest year
    # reloads every run. No column set is unique per line, so there is no primary key:
    # merge_key deletes the rows of every ordered_on in the load, then inserts, which
    # replaces the latest year whole. REFRESH=drop_data resets the state: all years reload.
    @dlt.resource(write_disposition={"disposition": "merge", "strategy": "delete-insert"}, merge_key="ordered_on")
    def sales():
        loaded = dlt.current.resource_state().setdefault("loaded_years", [])
        latest = max(sales_datasets)
        for year, dataset_id in sorted(sales_datasets.items()):
            if year in loaded:
                continue
            yield from read_csv_zip(dataset_id)
            if year != latest:
                loaded.append(year)

    return products, sales


if __name__ == "__main__":
    setup(__file__)
    pipeline = dlt.pipeline(pipeline_name="iowa_liquor", destination="postgres")
    # csv loads with COPY: much faster than INSERT for ~35M sales rows.
    report(pipeline, pipeline.run(iowa_liquor(), loader_file_format="csv"))
