# The database and its schemas (docs/architecture.md §4). dev (dbt_<user>_*) and
# CI (ci_pr_<n>_*) schemas are created by dbt, not here.
locals {
  # Each raw schema gets a *_staging twin for dlt's merge loads (§3).
  raw_schemas = ["raw_wordpress_vitlamdata", "raw_metabase", "raw_sheets"]

  # schema => owner. Add mart_<domain> schemas (owner transformer) as marts arrive.
  schemas = merge(
    { for s in local.raw_schemas : s => "loader" },
    { for s in local.raw_schemas : "${s}_staging" => "loader" },
    {
      staging      = "transformer"
      intermediate = "transformer"
      private      = "postgres" # pii_key (pii_key.sql)
    },
  )
}

# Owned by the superuser: no app role can alter or drop it.
resource "postgresql_database" "dw" {
  name  = "vitlamdata_dw"
  owner = "postgres"

  lifecycle {
    prevent_destroy = true
  }
}

# In `public`, so dbt's default search_path finds hmac() unqualified (§6).
# USAGE on `public` is granted only to the roles that call it (grants.tf).
resource "postgresql_extension" "pgcrypto" {
  name     = "pgcrypto"
  database = postgresql_database.dw.name
  schema   = "public"
}

resource "postgresql_schema" "this" {
  for_each = local.schemas

  database = postgresql_database.dw.name
  name     = each.key
  # postgres is the bootstrap superuser, not managed here.
  owner = each.value == "postgres" ? "postgres" : postgresql_role.login[each.value].name

  lifecycle {
    prevent_destroy = true
  }
}

# raw_wordpress was renamed for the source name wordpress_vitlamdata (#5). The
# provider renames a schema in place (ALTER SCHEMA ... RENAME), so contents and
# ACLs stay. Its grants are replaced: revoked before the rename, granted after.
moved {
  from = postgresql_schema.this["raw_wordpress"]
  to   = postgresql_schema.this["raw_wordpress_vitlamdata"]
}

moved {
  from = postgresql_schema.this["raw_wordpress_staging"]
  to   = postgresql_schema.this["raw_wordpress_vitlamdata_staging"]
}
