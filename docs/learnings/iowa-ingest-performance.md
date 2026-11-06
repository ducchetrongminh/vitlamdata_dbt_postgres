# From 3h45m to minutes: loading Iowa liquor sales

How a source rename turned into two days of ingest tuning, told in the order it
happened. Every number comes from an ingest log or a query on the warehouse;
links point to the PRs and workflow runs.

The data: Iowa liquor products and sales, 2012 to 2026, about 38M rows of CSV
from the Iowa Data Hub (data.iowa.gov). It loads with dlt into Postgres, on a
`cold` tablespace: a 20 GB `pd-standard` disk (HDD) formatted btrfs with zstd
compression ([#28](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/issues/28)).

## 1. A rename forces a full reload

The source was called `iowa_liquor`. Liquor is only one dataset on the Iowa
Data Hub, so the source became `iowa_data_hub`, named after the system we
extract from, and the tables got a dataset prefix: `liquor_products`,
`liquor_sales_<year>`
([#38](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/pull/38)).

Terraform renamed the schema in place with two `moved` blocks, so the data
survived. dlt did not: its saved state is keyed by pipeline name and table
name, both new. With no record that past years were loaded, the next ingest
would download and load all 15 years again. We dropped the old tables first,
because the disk had no room for two copies.

> **Lesson.** Renaming a dlt pipeline or resource resets its state. Plan the
> reload, and the disk space for it, before merging.

## 2. The nightly that took 3h45m

Nightly [42206816905](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42206816905) ran the reload. Its ingest job took
3h45m:

| Phase | Duration |
|---|--:|
| Extract (download 16 zips, read the CSVs) | 19m |
| Normalize (write load files) | 21m |
| Load (`COPY` into Postgres, 16 tables in parallel) | **3h04m** |

Loading was 81% of the time. Tables finished between 1 and 3 hours in, all
fighting over the same disk.

## 3. Finding the bottleneck

While the load ran, two measurements did not match:

| Where | Measured |
|---|--|
| `cold` disk, 30 s sample of `/proc/diskstats` | 100% busy, ~69 writes/s, ~4 MB/s |
| Table growth, from `pg_total_relation_size` | ~0.1 MB/s |

The disk wrote about 40 times more than landed as data. The suspect: dlt puts a
`UNIQUE` constraint on `_dlt_id` in every table it creates. `_dlt_id` is a
random string, so each new row updates a random page of a ~100 MB index per
year. At every checkpoint Postgres flushes those scattered pages, and a 20 GB
`pd-standard` disk allows only a few dozen writes per second.

The index bought nothing: these tables are replaced whole, and nothing reads a
raw row by `_dlt_id`. For `replace`, `append` and default merge loads,
`_dlt_id` is random on every load
([`get_root_row_id_type`](https://github.com/dlt-hub/dlt/blob/devel/dlt/common/normalizers/json/helpers.py)).
dlt adds it to link nested tables, and Iowa's rows are flat.

> **Lesson.** On a slow disk, an index on a random key turns a sequential bulk
> load into random writes. Check what indexes your loader creates.

## 4. Turning the index off

[#41](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/pull/41) set `create_indexes = false` for this pipeline only. The setting
applies when dlt creates a table, so the existing tables kept theirs. Dropping
it by hand hit a snag:

```
ERROR:  cannot drop index raw_iowa_data_hub.liquor_sales_2026__dlt_id_key
        because constraint liquor_sales_2026__dlt_id_key ... requires it
```

dlt creates a constraint, not a bare index, so the fix is
`alter table … drop constraint …__dlt_id_key`.

To test without another 3-hour run, the config loaded only 2026 (2.03M rows).
Ingest [42239674388](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42239674388):

| | Before (16 tables, index) | After (2026 alone, no index) |
|---|--:|--:|
| Load `liquor_sales_2026` | 2h03m | **1m51s** |
| Write rate | 0.1 MB/s of table growth | ~5 MB/s, about the disk's limit |

Running one table instead of 16 helps too, so the two numbers are not a clean
comparison. But the disk now writes about as fast as the table grows, which the
index had prevented.

## Side story: the run summary counted cells

The run summary claimed 50,731,138 rows for `liquor_sales_2026`; the table had
about 2M
([#31](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/issues/31)).
dlt's `CsvWriter` counts `sum(len(row) for row in items)`: columns per row, not
rows. Still true in dlt 1.32.0.
[#39](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/pull/39) takes the counts from the extract step instead, which counts rows
correctly.

> **Lesson.** Check a tool's metrics against the data at least once.

## 5. Arrow instead of dicts

The pipeline yielded lists of Python dicts. dlt walks every dict, and it adds
`_dlt_id` and `_dlt_load_id` to each row. For Arrow tables it adds neither by
default, and it handles the data column-wise.
[#42](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/pull/42) switched `read_csv_zip` to `pyarrow.csv`, with every column still
forced to text (codes keep leading zeros, staging casts) and empty cells still
NULL.

The switch tripped twice:

1. The old tables had `_dlt_id` and `_dlt_load_id` as `NOT NULL`, so they had to
   be dropped and recreated. A temporary `refresh = "drop_resources"` in
   `config.toml` was meant to do that. But the run was started with
   `full_refresh`, which exports `REFRESH=drop_data`, and an environment
   variable overrides `config.toml`. dlt only truncated the tables, kept the old
   columns, and every `COPY` failed
   ([42242950144](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42242950144)):
   `BadCopyFileFormat: missing data for column "_dlt_load_id"`.
2. Without `full_refresh`, `drop_resources` dropped and recreated the tables,
   then failed cleaning up the empty `raw_iowa_data_hub_staging` schema
   ([42243959379](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42243959379)):
   `relation "raw_iowa_data_hub_staging._dlt_version" does not exist`.
   The main tables were already rebuilt, so
   [#43](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/pull/43) simply removed the setting.

Then the numbers ([42246183686](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42246183686), 2026 only):

| | Dicts | Arrow |
|---|--:|--:|
| Extract | ~66s | ~26s |
| Normalize | 56s | 26s |
| Load 2026 | 1m51s | 1m51s |
| `liquor_sales_2026` size | 564 MB | **496 MB** (-12%) |

The first Arrow run had loaded in 4m26s
([42244724035](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42244724035)), right after two tables were dropped. A rerun
gave 1m51s, so we put it down to background cleanup on the disk.

> **Lesson.** Environment variables override dlt's `config.toml`. And one slow
> run is not a result: run it twice.

## 6. Parquet through ADBC: faster on paper

With Arrow, dlt's extract already writes Parquet, and for `csv` normalize
converts it to CSV, which Postgres then parses. dlt can instead load Parquet
through the ADBC driver, a binary `COPY`
([#44](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/pull/44)). On the way it exposed a latent bug: ADBC receives the
credentials as a URL, where the space in `-c default_tablespace=cold` became
`+`:

```
FATAL: unrecognized configuration parameter "+default_tablespace"
```

`-cdefault_tablespace=cold` works for both drivers.

The results, two runs each, 2026 only:

| | Arrow + csv | Parquet/ADBC ([42247646401](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42247646401)) | Parquet/ADBC ([42248695678](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/42248695678)) |
|---|--:|--:|--:|
| Normalize | 26s | ~0s | ~0s |
| Load 2026 | **1m51s** | 2m37s | 2m22s |
| Whole job | **4m37s** | 5m14s | 4m53s |

Skipping the conversion saved 26s, and the load lost more than that. Every
column here is text, so binary `COPY` saves Postgres little parsing, and its
length prefixes make the data slightly bigger.
[#45](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/pull/45) went back to Arrow + csv and removed the driver.

We also considered importing the publisher's CSV files as they are
(`dlt.mark.with_file_import`). It would skip extract and normalize, but save
only ~40-50s, and the run summary would lose its row count. Not worth it.

> **Lesson.** Measure the whole job, not the step a change targets.

## 7. The fresh reload

With every year back in the config, all tables in `raw_iowa_data_hub` were
dropped (the schemas stay: terraform owns them, and the `USAGE` grants go with
them), and ingest reloaded everything.

<!-- TODO: fill in from the fresh reload run. -->

Ingest [{{RUN_ID}}](https://github.com/ducchetrongminh/vitlamdata_dbt_postgres/actions/runs/{{RUN_ID}}):

| | First reload (nightly 42206816905) | Fresh reload |
|---|--:|--:|
| Extract | 19m | {{EXTRACT}} |
| Normalize | 21m | {{NORMALIZE}} |
| Load (16 tables) | 3h04m | {{LOAD}} |
| Whole ingest job | 3h45m | {{TOTAL}} |
| Size of `raw_iowa_data_hub` | {{SIZE_BEFORE}} | {{SIZE_AFTER}} |

{{ONE_SENTENCE_RESULT}}

## What we keep

- `create_indexes = false` for bulk raw loads, and no index on random keys.
- Arrow + csv for this source: every column text, no dlt columns per row.
- `report()` row counts from the extract step.
- `-cdefault_tablespace=cold`, with no space.
- Before merging a rename: plan the reload and the disk space it needs.
