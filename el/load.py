"""Extract-load with dlt: one pipeline per source (docs/architecture.md §3).

    python el/load.py --source wordpress_vitlamdata
    python el/load.py --source wordpress_vitlamdata --full-refresh
    python el/load.py --source wordpress_vitlamdata --dataset dbt_duc_raw_wordpress_vitlamdata

Reads the source login from MARIADB_* and writes to the warehouse with the PG*
vars (.env.example). Nightly runs it as `loader` into raw_<source>; a personal
login cannot write there, so test locally with --dataset.
"""

import argparse
import os

import dlt
from dlt.sources.sql_database import sql_database
from sqlalchemy import URL

# table => cursor column for a `merge` load, or None for `replace`. Use merge
# whenever the table has a cursor that changes on every update (architecture §3),
# however small the table. A table with no such column can only be replaced.
# Only the tables for courses, enrollments, sales and users; add more as models
# need them (RUNBOOK.md). Never add wp_options: it can hold API keys and SMTP
# passwords.
WORDPRESS_VITLAMDATA_TABLES = {
    # courses, topics, lessons, bundles, enrollments (tutor_enrolled), leads (vld_lead)
    "wp_posts": "post_modified_gmt",
    "wp_postmeta": None,
    "wp_users": None,
    "wp_usermeta": None,
    # course categories and tags
    "wp_terms": None,
    "wp_term_taxonomy": None,
    "wp_term_relationships": None,
    # Tutor does not bump updated_at_gmt when an order is paid or cancelled, or a
    # coupon edited. Merge on it after vitlamdata_infras#156 fixes that.
    "wp_tutor_orders": None,
    "wp_tutor_coupons": None,
    "wp_tutor_ordermeta": "updated_at_gmt",
    "wp_tutor_order_items": None,
    "wp_tutor_coupon_usages": None,
    "wp_tutor_customers": None,
    "wp_tutor_earnings": None,
}

# Credentials never leave WordPress: password hashes, reset keys, login sessions.
SECRET_COLUMNS = {"wp_users": ["user_pass", "user_activation_key"]}
SECRET_USERMETA_KEYS = ["session_tokens", "_application_passwords"]


def drop_secret_columns(table):
    for name in SECRET_COLUMNS.get(table.name, []):
        table._columns.remove(table.c[name])


def skip_secret_rows(query, table):
    if table.name == "wp_usermeta":
        return query.where(table.c.meta_key.not_in(SECRET_USERMETA_KEYS))
    return query


def wordpress_vitlamdata():
    url = URL.create(
        "mysql+pymysql",
        username=os.environ["MARIADB_USER"],
        password=os.environ["MARIADB_PASSWORD"],
        host=os.environ["MARIADB_HOST"],
        port=int(os.environ["MARIADB_PORT"]),
        database=os.environ["MARIADB_DATABASE"],
    )
    source = sql_database(
        url.render_as_string(hide_password=False),
        table_names=list(WORDPRESS_VITLAMDATA_TABLES),
        table_adapter_callback=drop_secret_columns,
        query_adapter_callback=skip_secret_rows,
    )
    for table, cursor in WORDPRESS_VITLAMDATA_TABLES.items():
        if cursor:
            # The primary key is reflected from the source table.
            source.resources[table].apply_hints(
                write_disposition="merge", incremental=dlt.sources.incremental(cursor)
            )
        else:
            source.resources[table].apply_hints(write_disposition="replace")
    return source


SOURCES = {"wordpress_vitlamdata": wordpress_vitlamdata}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", required=True, choices=SOURCES)
    parser.add_argument(
        "--full-refresh",
        action="store_true",
        help="reload every table with replace, and reset incremental cursors (catches hard deletes)",
    )
    parser.add_argument("--dataset", help="target schema; default raw_<source>")
    args = parser.parse_args()

    dataset = args.dataset or f"raw_{args.source}"
    warehouse = dlt.destinations.postgres(
        credentials={
            "username": os.environ["PGUSER"],
            "password": os.environ["PGPASSWORD"],
            "host": os.environ["PGHOST"],
            "port": int(os.environ["PGPORT"]),
            "database": os.environ["PGDATABASE"],
        }
    )
    # One pipeline per target schema, so a dev load never shares cursor state with prod.
    pipeline = dlt.pipeline(pipeline_name=dataset, destination=warehouse, dataset_name=dataset)
    source = SOURCES[args.source]()
    if args.full_refresh:
        info = pipeline.run(source, write_disposition="replace", refresh="drop_data")
    else:
        info = pipeline.run(source)
    print(info)


if __name__ == "__main__":
    main()
