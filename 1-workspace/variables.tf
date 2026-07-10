variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create for the workspace."
  default     = "rg-databricks-lakewatch"
}

variable "location" {
  type        = string
  description = "Azure region. Note: Unity Catalog allows one metastore per region per account."
  default     = "centralindia"
}

variable "prefix" {
  type        = string
  description = "Short prefix for resource names (lowercase, no spaces)."
  default     = "clbl-lw"
}

variable "workspace_name" {
  type        = string
  description = "Databricks workspace name."
  default     = "clbl-lakewatch-poc"
}

variable "vnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "storage_account_name" {
  type        = string
  description = "Globally-unique ADLS Gen2 account name (3-24 chars, lowercase letters/numbers only)."
}

variable "storage_replication_type" {
  type        = string
  default     = "ZRS"
  description = "LRS / ZRS / GZRS. Use LRS if your region does not support ZRS."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "Keep true so the workspace is reachable without Private Link. Set false only if you also deploy Private Link endpoints."
}

variable "tags" {
  type = map(string)
  default = {
    project = "lakewatch-poc"
    owner   = "celebal"
  }
}
