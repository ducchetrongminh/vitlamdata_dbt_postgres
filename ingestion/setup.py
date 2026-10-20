"""Shared by ingestion/<source>/pipeline.py: setup(__file__) first, report() after the run."""

import os
import tomllib
from string import Template

import dlt
from dlt.common.configuration.providers import CustomLoaderDocProvider

CREDENTIALS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "credentials.toml")


def _expand(value):
    # Template.substitute raises KeyError on an unset var instead of passing "${VAR}" on.
    if isinstance(value, dict):
        return {k: _expand(v) for k, v in value.items()}
    return Template(value).substitute(os.environ) if isinstance(value, str) else value


def _load_credentials():
    with open(CREDENTIALS, "rb") as f:
        return _expand(tomllib.load(f))


def setup(pipeline_file):
    # dlt reads .dlt/ from the working directory; use the source's own folder, so
    # each source keeps its config.toml and the script runs from anywhere.
    os.environ.setdefault("DLT_PROJECT_DIR", os.path.dirname(os.path.abspath(pipeline_file)))
    dlt.config.register_provider(CustomLoaderDocProvider("credentials.toml", _load_credentials, locations=[CREDENTIALS]))


def report(pipeline, load_info):
    """Print rows loaded per table, and add them to the GitHub Actions run summary.

    Every source in a job writes to the same summary, so the header goes in once
    and each source adds its rows to one table.
    """
    rows = pipeline.last_trace.last_normalize_info.row_counts
    header = "| Source | Dataset | Table | Write disposition | Rows |\n|---|---|---|---|--:|\n"
    body = ""
    # Every table, so a merge table with no new rows shows 0 instead of vanishing.
    for table in sorted(pipeline.default_schema.data_table_names()):
        disposition = pipeline.default_schema.tables[table].get("write_disposition", "")
        body += (
            f"| {pipeline.pipeline_name} | `{pipeline.dataset_name}` | `{table}` "
            f"| {disposition} | {rows.get(table, 0)} |\n"
        )

    print(load_info)
    print(header + body)
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(summary, "a+") as f:
            f.seek(0)
            if not f.read():
                f.write("### Rows loaded\n\n" + header)
            f.write(body)
