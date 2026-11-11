# Who can see what, as two matrices like Metabase's Admin > Permissions page:
# one row per database or collection, one column per group. Edit a cell to
# change access. Every cell is one resource, and only the cells listed here
# are managed. The provider's graph resources are not used: they would also
# take over every collection learners create.
#
# A user gets the highest access of all their groups, and everyone is in
# all_users. Administrators (2) always have full access and are not listed.
locals {
  # Column => Metabase group id. All Users (1) is built in, not a resource.
  # Plain ids, not resource references: import blocks need them before apply.
  permission_group_ids = {
    all_users    = 1
    learners     = local.groups.learners.id
    vit_lam_data = local.groups.vit_lam_data.id
  }

  # Data access: "Create queries", per database. Values:
  #   query-builder-and-native  query builder and SQL
  #   query-builder             query builder only
  #   no                        only through saved questions
  # "View data" is "unrestricted" for every cell: the only free-plan value.
  # Download permissions are a paid feature and are not managed.
  database_access = {
    sales_normalized = { all_users = "query-builder-and-native", learners = "query-builder-and-native", vit_lam_data = "query-builder-and-native" }
    sales            = { all_users = "query-builder-and-native", learners = "query-builder-and-native", vit_lam_data = "query-builder-and-native" }
    metabase_app     = { all_users = "no", learners = "no", vit_lam_data = "no" }
    duck_data        = { all_users = "query-builder-and-native", learners = "query-builder-and-native", vit_lam_data = "query-builder-and-native" }
  }

  # Collection access. Values: write (curate), read (view), none (no access).
  # Rows are the keys in collections.tf, plus Metabase's root collection.
  # A managed collection with no row takes its parent's row, or its
  # grandparent's: so sql_course's row covers every season and test under it.
  # Add a row for a sub-collection to give it its own access.
  collection_access = {
    root           = { all_users = "read", learners = "read", vit_lam_data = "write" }
    learners       = { all_users = "write", learners = "write", vit_lam_data = "write" }
    sql_thuc_chien = { all_users = "read", learners = "read", vit_lam_data = "write" }
    sql_course     = { all_users = "read", learners = "read", vit_lam_data = "read" }
  }

  # shortcut: inheritance looks up two levels only (enough for course > season
  # > test). Add a level here if a deeper collection is ever managed. A
  # collection with no row in reach fails the plan instead of being skipped.
  collection_key_by_id = { for key, c in local.collections : c.id => key }
  collection_access_inherited = merge({ root = local.collection_access.root }, {
    for key, c in local.collections : key => try(
      local.collection_access[key],
      local.collection_access[local.collection_key_by_id[c.parent]],
      local.collection_access[local.collection_key_by_id[local.collections[local.collection_key_by_id[c.parent]].parent]],
    )
  })

  # The matrices as one entry per cell, keyed "<group>/<row>".
  database_permissions = merge([
    for database, row in local.database_access : {
      for group, create_queries in row : "${group}/${database}" => { group = group, database = database, create_queries = create_queries }
    }
  ]...)

  collection_permissions = merge([
    for collection, row in local.collection_access_inherited : {
      for group, permission in row : "${group}/${collection}" => { group = group, collection = collection, permission = permission }
    }
  ]...)
}

resource "metabase_database_permission" "this" {
  for_each = local.database_permissions

  group          = local.permission_group_ids[each.value.group]
  database       = metabase_database.this[each.value.database].id
  view_data      = "unrestricted"
  create_queries = each.value.create_queries
}

resource "metabase_collection_permission" "this" {
  for_each = local.collection_permissions

  group      = local.permission_group_ids[each.value.group]
  collection = each.value.collection == "root" ? "root" : metabase_collection.this[each.value.collection].id
  permission = each.value.permission
}

# shortcut: one-time adoption of the existing permissions. Delete these blocks
# after the apply that imports them.
import {
  for_each = local.database_permissions

  to = metabase_database_permission.this[each.key]
  id = "${local.permission_group_ids[each.value.group]}/${local.databases[each.value.database].id}"
}

import {
  for_each = local.collection_permissions

  to = metabase_collection_permission.this[each.key]
  id = "${local.permission_group_ids[each.value.group]}/${each.value.collection == "root" ? "root" : local.collections[each.value.collection].id}"
}
