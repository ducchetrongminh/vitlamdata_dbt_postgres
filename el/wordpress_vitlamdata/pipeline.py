"""WordPress + Tutor LMS (MariaDB) -> raw_wordpress_vitlamdata.

Tables, write dispositions and cursors: .dlt/config.toml next to this file.
Credentials: env vars (.env.example). From the repo root:

    python el/wordpress_vitlamdata/pipeline.py
"""

import os

# dlt reads .dlt/ from the working directory; point it at this source's folder
# instead, so the script runs from anywhere.
os.environ.setdefault("DLT_PROJECT_DIR", os.path.dirname(os.path.abspath(__file__)))

import dlt  # noqa: E402
from dlt.sources.sql_database import sql_database  # noqa: E402


def skip_login_sessions(query, table):
    # Login sessions (IPs, user agents) and app passwords stay in WordPress.
    if table.name == "wp_usermeta":
        return query.where(table.c.meta_key.not_in(["session_tokens", "_application_passwords"]))
    return query


if __name__ == "__main__":
    source = sql_database.with_args(name="wordpress_vitlamdata", section="wordpress_vitlamdata")(
        query_adapter_callback=skip_login_sessions
    )
    pipeline = dlt.pipeline(pipeline_name="wordpress_vitlamdata", destination="postgres")
    print(pipeline.run(source))
