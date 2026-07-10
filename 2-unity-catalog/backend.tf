# Remote state in Azure Storage (partial config; see backend.hcl.example).
terraform {
  backend "azurerm" {
    key              = "lakewatch-uc.tfstate"
    use_azuread_auth = true
  }
}
