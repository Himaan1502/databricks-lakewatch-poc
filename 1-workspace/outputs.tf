# ---- Details to paste into the email to Ashish ----

output "workspace_name" {
  value = azurerm_databricks_workspace.this.name
}

output "workspace_url" {
  description = "Workspace URL — include in the email."
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "workspace_id" {
  description = "Databricks workspace ID — include in the email."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "workspace_azure_resource_id" {
  description = "Full Azure resource ID of the workspace (also used by Stage 2)."
  value       = azurerm_databricks_workspace.this.id
}

output "location" {
  value = azurerm_databricks_workspace.this.location
}

output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "managed_resource_group" {
  value = azurerm_databricks_workspace.this.managed_resource_group_name
}

# ---- Consumed by Stage 2 (Unity Catalog) ----

output "telemetry_storage_account" {
  value = azurerm_storage_account.telemetry.name
}

output "telemetry_filesystem_abfss" {
  description = "ABFSS path for the security landing zone (Stage 2 external location)."
  value       = "abfss://${azurerm_storage_data_lake_gen2_filesystem.security.name}@${azurerm_storage_account.telemetry.name}.dfs.core.windows.net/"
}

output "uc_access_connector_id" {
  description = "Access Connector resource ID (Stage 2 storage credential)."
  value       = azurerm_databricks_access_connector.uc.id
}
