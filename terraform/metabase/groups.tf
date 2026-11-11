# Permission groups. Deleting one also drops its members and its permissions,
# hence prevent_destroy. Members are not managed here.
#
# Not managed: the built-in groups "All Users" (id 1) and "Administrators"
# (id 2). Metabase creates them and they cannot be deleted; refer to them by id.
locals {
  groups = {
    learners     = { id = 4, name = "Learners" }
    vit_lam_data = { id = 5, name = "Vịt làm Data" }
  }
}

resource "metabase_permissions_group" "this" {
  for_each = local.groups

  name = each.value.name

  lifecycle {
    prevent_destroy = true
  }
}
