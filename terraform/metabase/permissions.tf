# Who can see what, one (group, database) or (group, collection) pair per
# resource. Only the pairs listed here are managed: the provider's graph
# resources would also take over every collection learners create, so they are
# not used.
#
# A user gets the highest access of all their groups, and everyone is in
# All Users. So a group's own grant only matters where it is above All Users'.
#
# Administrators (2) always have full access and are not listed.
locals {
  # Group key => Metabase group id. All Users (1) is built in, not a resource.
  # Plain ids, not resource references: import blocks need them before apply.
  permission_group_ids = {
    all_users    = 1
    learners     = local.groups.learners.id
    vit_lam_data = local.groups.vit_lam_data.id
  }

  # Data access. Every group can see all data; create_queries is what differs.
  # Database 4 is Metabase's own app database: no group may query it, so it is
  # only seen through questions admins save. `download` is left unmanaged:
  # download permissions are a paid feature.
  database_create_queries = {
    sales_normalized = "query-builder-and-native"
    sales            = "query-builder-and-native"
    metabase_app     = "no"
    duck_data        = "query-builder-and-native"
  }

  database_permissions = {
    for pair in setproduct(keys(local.permission_group_ids), keys(local.database_create_queries)) :
    "${pair[0]}/${pair[1]}" => { group = pair[0], database = pair[1] }
  }

  # Collection access: each group's level on root and every managed
  # collection, with exceptions listed by collection key.
  collection_access = {
    all_users    = { default = "read", write = ["learners"] }
    learners     = { default = "read", write = ["learners"] }
    vit_lam_data = { default = "read", write = ["root", "learners", "sql_thuc_chien"] }
  }

  collection_permissions = {
    for pair in setproduct(keys(local.collection_access), concat(["root"], keys(local.collections))) :
    "${pair[0]}/${pair[1]}" => {
      group      = pair[0]
      collection = pair[1]
      permission = contains(local.collection_access[pair[0]].write, pair[1]) ? "write" : local.collection_access[pair[0]].default
    }
  }
}

resource "metabase_database_permission" "this" {
  for_each = local.database_permissions

  group          = local.permission_group_ids[each.value.group]
  database       = metabase_database.this[each.value.database].id
  view_data      = "unrestricted"
  create_queries = local.database_create_queries[each.value.database]
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
