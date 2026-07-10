# Remote state in Azure Storage (blob-lease locking is automatic).
# Partial config: coordinates are supplied at init via -backend-config so the
# same file works locally and in CI. See backend.hcl.example.
#
# Distinct key from the observability stacks, so this can share the same state
# storage account/container without collision.
terraform {
  backend "azurerm" {
    key              = "lakewatch-workspace.tfstate"
    use_azuread_auth = true # authenticate to the state blob as the logged-in identity / SPN
  }
}
