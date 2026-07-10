###############################################################################
# Stage 2 — Unity Catalog data landing zone for the Lakewatch PoC
#
# Reads Stage 1's outputs from remote state, so no manual value copying — the
# pipeline (or a local run) chains stage 1 -> stage 2 automatically.
#
# The principal running this (your SPN in CI, or you locally) must be a Unity
# Catalog metastore admin, or hold CREATE STORAGE CREDENTIAL / EXTERNAL LOCATION
# / CATALOG privileges. In CI, auth is the same ARM_* service-principal env vars.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# Stage 1 outputs (workspace URL, resource id, access connector, storage path)
data "terraform_remote_state" "workspace" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = "lakewatch-workspace.tfstate"
    use_azuread_auth     = true
  }
}

# Authenticate to the workspace created in Stage 1.
# In CI: uses the ARM_* service-principal env vars automatically.
# Locally: run `az login` first (Azure CLI auth).
provider "databricks" {
  host                        = data.terraform_remote_state.workspace.outputs.workspace_url
  azure_workspace_resource_id = data.terraform_remote_state.workspace.outputs.workspace_azure_resource_id
}

# Storage credential backed by the Stage 1 Access Connector managed identity
resource "databricks_storage_credential" "security" {
  name    = "lakewatch-security-cred"
  comment = "Managed identity credential for Lakewatch security telemetry"

  azure_managed_identity {
    access_connector_id = data.terraform_remote_state.workspace.outputs.uc_access_connector_id
  }
}

# External location pointing at the Stage 1 ADLS Gen2 filesystem
resource "databricks_external_location" "security" {
  name            = "lakewatch-security-loc"
  url             = data.terraform_remote_state.workspace.outputs.telemetry_filesystem_abfss
  credential_name = databricks_storage_credential.security.name
  comment         = "Landing zone for security telemetry"
}

# Governed catalog + schema for the PoC data
resource "databricks_catalog" "security" {
  name         = "security"
  comment      = "Catalog for Lakewatch / security telemetry"
  storage_root = "${data.terraform_remote_state.workspace.outputs.telemetry_filesystem_abfss}managed"

  depends_on = [databricks_external_location.security]
}

resource "databricks_schema" "raw" {
  catalog_name = databricks_catalog.security.name
  name         = "raw"
  comment      = "Raw / OCSF-normalized logs"
}
