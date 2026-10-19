# Database, schema and default-privilege grants (docs/architecture.md §7).
# Grants live only here; dbt has no +grants config.
#
# Tables get SELECT from default privileges only: every schema here is new, so
# no table predates them. dbt rebuilds tables as new objects on every run, and
# the default privileges cover each one. If a grantee is ever added after tables
# exist, add a postgresql_grant with object_type "table" for the existing ones.
#
# Grants on the same database or schema update one catalog row. Run in parallel
# they fail with `pq: tuple concurrently updated`, so apply with -parallelism=1
# (RUNBOOK.md).
locals {
  # role => database privileges. TEMPORARY because PUBLIC loses it below, and
  # dbt incremental models and dlt merge loads create temp tables.
  database_privileges = {
    loader          = ["CONNECT", "TEMPORARY"]
    transformer     = ["CONNECT", "TEMPORARY"]
    developer       = ["CONNECT", "TEMPORARY", "CREATE"] # CREATE: dev and CI schemas
    reporter_public = ["CONNECT"]                        # mart grants come with the first marts (#11)
  }

  # role => schemas it may read but does not own. Owners need no grant.
  schema_readers = {
    transformer = concat(local.raw_schemas, ["private", "public"])
    developer   = concat(local.raw_schemas, ["staging", "intermediate", "private", "public"])
  }

  schema_usage = merge([
    for role, schemas in local.schema_readers : {
      for s in schemas : "${role}.${s}" => { role = role, schema = s }
    }
  ]...)

  # owner => roles that get SELECT on every table it creates, in any schema.
  table_readers = {
    loader      = ["transformer", "developer"]
    transformer = ["developer"]
  }

  default_select = merge([
    for owner, roles in local.table_readers : {
      for role in roles : "${owner}.${role}" => { owner = owner, role = role }
    }
  ]...)

  role_names = merge(
    { for name, r in postgresql_role.login : name => r.name },
    { developer = postgresql_role.developer.name },
  )
}

# REVOKE ALL ON DATABASE vitlamdata_dw FROM PUBLIC.
resource "postgresql_grant" "database_public" {
  database    = postgresql_database.dw.name
  role        = "public"
  object_type = "database"
  privileges  = []
}

resource "postgresql_grant" "database" {
  for_each = local.database_privileges

  database    = postgresql_database.dw.name
  role        = local.role_names[each.key]
  object_type = "database"
  privileges  = each.value
}

# REVOKE ALL ON SCHEMA public FROM PUBLIC. Only pgcrypto lives there.
resource "postgresql_grant" "schema_public_public" {
  database    = postgresql_database.dw.name
  role        = "public"
  object_type = "schema"
  schema      = "public"
  privileges  = []
}

resource "postgresql_grant" "schema_usage" {
  for_each = local.schema_usage

  database    = postgresql_database.dw.name
  role        = local.role_names[each.value.role]
  object_type = "schema"
  # `public` exists with the database; the others are this module's.
  schema     = each.value.schema == "public" ? "public" : postgresql_schema.this[each.value.schema].name
  privileges = ["USAGE"]
}

# ALTER DEFAULT PRIVILEGES FOR ROLE <owner> GRANT SELECT ON TABLES TO <role>,
# in every schema. Covers views too.
resource "postgresql_default_privileges" "select" {
  for_each = local.default_select

  database    = postgresql_database.dw.name
  owner       = local.role_names[each.value.owner]
  role        = local.role_names[each.value.role]
  object_type = "table"
  privileges  = ["SELECT"]
}

# private.pii_key is created by pii_key.sql as postgres, after apply; this gives
# it its grants when it appears.
resource "postgresql_default_privileges" "private" {
  for_each = toset(["transformer", "developer"])

  database    = postgresql_database.dw.name
  owner       = "postgres"
  role        = local.role_names[each.key]
  schema      = postgresql_schema.this["private"].name
  object_type = "table"
  privileges  = ["SELECT"]
}
