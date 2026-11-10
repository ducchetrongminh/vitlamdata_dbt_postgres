# Metabase as code: its database connection, collections, groups and
# permissions. Cards and dashboards are not managed here.
#
# Its own root module and state, apart from the warehouse in ../, so a Metabase
# outage or an API break never blocks a warehouse apply.
terraform {
  required_version = ">= 1.11" # ephemeral values in provider config

  required_providers {
    # The Metabase API is unversioned and breaks between releases. Check the
    # provider's compatibility table before upgrading either one.
    metabase = {
      source  = "flovouin/metabase"
      version = "~> 0.19.0" # supports Metabase .57 to .63
    }
    # Only for the ephemeral secret read below.
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  backend "gcs" {
    bucket = "vitlamdata_dbt_postgres"
    prefix = "metabase"
  }
}

provider "google" {
  project = "vit-lam-data"
}

# Read on every plan and apply, never stored in state.
ephemeral "google_secret_manager_secret_version" "api_key" {
  secret = "metabase-api-key"
}

provider "metabase" {
  endpoint = "https://metabase.vitlamdata.com/api"
  api_key  = ephemeral.google_secret_manager_secret_version.api_key.secret_data
}
