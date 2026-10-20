"""WordPress + Tutor LMS (MariaDB) -> raw_wordpress_vitlamdata.

Tables, write dispositions and cursors: .dlt/config.toml next to this file.
Credentials: ingestion/credentials.toml. From the repo root:

    python -m ingestion.wordpress_vitlamdata.pipeline
"""

import dlt
from dlt.sources.sql_database import sql_database

from ingestion.setup import setup


def skip_login_sessions(query, table):
    # Login sessions (IPs, user agents) and app passwords stay in WordPress.
    if table.name == "wp_usermeta":
        return query.where(table.c.meta_key.not_in(["session_tokens", "_application_passwords"]))
    return query


if __name__ == "__main__":
    setup(__file__)
    source = sql_database.with_args(name="wordpress_vitlamdata", section="wordpress_vitlamdata")(
        query_adapter_callback=skip_login_sessions
    )
    pipeline = dlt.pipeline(pipeline_name="wordpress_vitlamdata", destination="postgres")
    print(pipeline.run(source))
