# Role names are instance-global on postgres-dw. They do not clash with the
# infras roles (duck_data*, sales*), which infras postgres/ manages.
#
# Each login role reads its password from its own Secret Manager secret
# (infras gcp/dbt.tf) as an ephemeral value and gets it through the write-only
# `password_wo`, so no password lands in state or in a plan.
locals {
  login_roles = {
    loader          = "dw-loader"
    transformer     = "dw-transformer"
    ci              = "dw-ci"
    reporter_public = "dw-reporter-public"
  }

  # Bump this to send every password to Postgres again; it is how a rotation
  # reaches the roles. Terraform cannot see a write-only value change by itself.
  password_version = "1"
}

# Read on every plan and apply, never stored. A trailing newline (from `echo`)
# would become part of the password, so whitespace is refused.
ephemeral "google_secret_manager_secret_version" "role" {
  for_each = local.login_roles

  secret = each.value

  lifecycle {
    postcondition {
      condition     = can(regex("^\\S+$", self.secret_data))
      error_message = "Secret ${each.value} must be non-empty with no whitespace or newline. Add it with: printf %s \"$(openssl rand -hex 32)\" | gcloud secrets versions add ${each.value} --data-file=-"
    }
  }
}

resource "postgresql_role" "login" {
  for_each = local.login_roles

  name                = each.key
  login               = true
  password_wo         = ephemeral.google_secret_manager_secret_version.role[each.key].secret_data
  password_wo_version = local.password_version
  roles               = each.key == "ci" ? [postgresql_role.developer.name] : []

  lifecycle {
    prevent_destroy = true
  }
}

# Group role: CI and personal dev logins get their privileges through it.
resource "postgresql_role" "developer" {
  name  = "developer"
  login = false

  lifecycle {
    prevent_destroy = true
  }
}

# Personal dev logins. No password here: each person sets their own once with
# `\password <name>` (RUNBOOK.md). The provider leaves a password it does not
# manage alone, so plan stays clean.
resource "postgresql_role" "dev" {
  for_each = toset(["duc"])

  name  = each.key
  login = true
  roles = [postgresql_role.developer.name]

  lifecycle {
    prevent_destroy = true
  }
}
