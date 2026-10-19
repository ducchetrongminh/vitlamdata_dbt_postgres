"""Extract-load with dlt: one source per system (docs/architecture.md §3).

    python el/load.py --source wordpress_vitlamdata
    python el/load.py --source wordpress_vitlamdata --full-refresh
    python el/load.py --source wordpress_vitlamdata --dataset dbt_duc_raw_wordpress_vitlamdata

Logins come from MARIADB_* and PG* (.env.example). Nightly runs it as `loader`
into raw_<source>; a personal login cannot write there, so test with --dataset.
"""

import argparse
import os

import dlt
from dlt.sources.sql_database import sql_table
from sqlalchemy import URL


@dlt.source
def wordpress_vitlamdata():
    """WordPress + Tutor LMS: courses, enrollments, sales, users.

    merge: the table has a cursor that changes on every update (architecture §3).
    replace: it has none. Never load wp_options: it can hold API keys.
    """
    db = URL.create(
        "mysql+pymysql",
        username=os.environ["MARIADB_USER"],
        password=os.environ["MARIADB_PASSWORD"],
        host=os.environ["MARIADB_HOST"],
        port=int(os.environ["MARIADB_PORT"]),
        database=os.environ["MARIADB_DATABASE"],
    ).render_as_string(hide_password=False)

    # Courses, topics, lessons, bundles, enrollments (tutor_enrolled), leads (vld_lead).
    yield sql_table(db, "wp_posts", write_disposition="merge",
                    incremental=dlt.sources.incremental("post_modified_gmt"))
    yield sql_table(db, "wp_tutor_ordermeta", write_disposition="merge",
                    incremental=dlt.sources.incremental("updated_at_gmt"))

    # Password hashes, reset keys and login sessions stay in WordPress.
    yield sql_table(db, "wp_users", write_disposition="replace",
                    excluded_columns=["user_pass", "user_activation_key"])
    yield sql_table(db, "wp_usermeta", write_disposition="replace",
                    query_adapter_callback=lambda query, table: query.where(
                        table.c.meta_key.not_in(["session_tokens", "_application_passwords"])))

    # Tutor never bumps updated_at_gmt on wp_tutor_orders and wp_tutor_coupons:
    # move them to merge after vitlamdata_infras#156.
    for table in [
        "wp_postmeta",
        "wp_terms", "wp_term_taxonomy", "wp_term_relationships",  # course categories and tags
        "wp_tutor_orders", "wp_tutor_order_items", "wp_tutor_coupons",
        "wp_tutor_coupon_usages", "wp_tutor_customers", "wp_tutor_earnings",
    ]:
        yield sql_table(db, table, write_disposition="replace")


SOURCES = {"wordpress_vitlamdata": wordpress_vitlamdata}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", required=True, choices=SOURCES)
    parser.add_argument("--full-refresh", action="store_true",
                        help="reload every table with replace and reset cursors (catches hard deletes)")
    parser.add_argument("--dataset", help="target schema; default raw_<source>")
    args = parser.parse_args()

    dataset = args.dataset or f"raw_{args.source}"
    pipeline = dlt.pipeline(
        pipeline_name=dataset,  # one per schema, so a dev load never shares cursors with prod
        dataset_name=dataset,
        destination=dlt.destinations.postgres(credentials={
            "username": os.environ["PGUSER"],
            "password": os.environ["PGPASSWORD"],
            "host": os.environ["PGHOST"],
            "port": int(os.environ["PGPORT"]),
            "database": os.environ["PGDATABASE"],
        }),
    )
    source = SOURCES[args.source]()
    if args.full_refresh:
        print(pipeline.run(source, write_disposition="replace", refresh="drop_data"))
    else:
        print(pipeline.run(source))
