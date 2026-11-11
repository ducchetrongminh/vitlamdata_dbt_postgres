# Database connections in Metabase. Deleting one also deletes every question and
# dashboard built on it, hence prevent_destroy.
#
# `details` must list every attribute Metabase returns, exactly: a missing one
# shows as a change, and the update would drop it in Metabase.
#
# password = "**MetabasePass**" is Metabase's own placeholder for a stored
# password, not a secret. Sent back, it tells Metabase to keep the stored one,
# so these connections need no password here. To set a real one, move
# `password` into custom_details.sensitive_details_json_wo.
#
# Not managed: "Sample Database" (id 6), Metabase's built-in demo.
locals {
  # The old warehouses on postgres-dw (infras#124 retires them).
  old_dw_details = {
    "additional-options"    = "readOnly=true"
    "admin-connection"      = false
    "advanced-options"      = false
    "destination-database"  = false
    "host"                  = "postgres-dw"
    "password"              = "**MetabasePass**"
    "port"                  = 5432
    "schema-filters-type"   = "all"
    "ssl"                   = false
    "tunnel-enabled"        = false
    "write-data-connection" = false
  }

  databases = {
    sales_normalized = {
      id      = 2
      name    = "Sales (normalized)"
      details = merge(local.old_dw_details, { dbname = "sales_normalized", user = "sales_normalized_read_only" })
    }
    sales = {
      id      = 3
      name    = "Sales Database"
      details = merge(local.old_dw_details, { dbname = "sales", user = "sales_read_only" })
    }
    # Metabase's own app database, for usage analysis.
    metabase_app = {
      id   = 4
      name = "Metabase"
      details = {
        "additional-options" = "readOnly=true"
        "dbname"             = "metabase_db"
        "host"               = "postgres"
        "password"           = "**MetabasePass**"
        "port"               = 5432
        "ssl"                = false
        "tunnel-enabled"     = false
        "user"               = "metabase_su"
      }
    }
    duck_data = {
      id      = 5
      name    = "Vịt làm Data"
      details = merge(local.old_dw_details, { dbname = "duck_data", user = "duck_data_read_only" })
    }
  }
}

# shortcut: one-time adoption of the existing connections. Delete these blocks
# after the apply that imports them.
import {
  for_each = local.databases

  to = metabase_database.this[each.key]
  id = tostring(each.value.id)
}

resource "metabase_database" "this" {
  for_each = local.databases

  name = each.value.name

  custom_details = {
    engine       = "postgres"
    details_json = jsonencode(each.value.details)
  }

  lifecycle {
    prevent_destroy = true
  }
}
