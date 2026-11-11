# Database connections in Metabase. Deleting one also deletes every question and
# dashboard built on it, hence prevent_destroy.
#
# Passwords are not managed here. On update, Metabase merges the sent details
# into the stored ones (warehouses_rest/api.clj, upsert-sensitive-fields), so an
# attribute left out of `details`, like `password`, keeps its stored value. To
# set a password from code, send it through
# custom_details.sensitive_details_json_wo.
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
