# The warehouse database vitlamdata_dw: its roles, schemas and grants
# (docs/architecture.md §4, §7, §9). Tables are dbt's and dlt's, not this module's.
#
# Logs in as the postgres-dw superuser through the SSH tunnel, so host/port
# below are the local end of that tunnel (RUNBOOK.md, "Open the tunnel").
terraform {
  required_version = ">= 1.11" # write-only password_wo (roles.tf)

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.27"
    }
    # Only for the ephemeral secret reads in roles.tf.
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # This repo's own bucket (infras gcp/dbt.tf), not infras' vit-lam-data-tfstate.
  backend "gcs" {
    bucket = "vitlamdata_dbt_postgres"
    prefix = "warehouse"
  }
}

provider "google" {
  project = "vit-lam-data"
}

# No password argument: the provider reads PGPASSWORD from the environment, so
# the superuser password never lands in state or in a .tfvars file.
provider "postgresql" {
  host            = "127.0.0.1"
  port            = 5433
  username        = "postgres"
  database        = "postgres"
  sslmode         = "disable" # plain TCP, but only inside the SSH tunnel
  superuser       = true
  connect_timeout = 15
}
