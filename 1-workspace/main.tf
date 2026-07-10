###############################################################################
# Stage 1 — Azure Databricks workspace (Lakewatch-ready foundation)
#
# Creates a Premium, VNet-injected workspace with secure cluster connectivity
# (no public IP), plus the ADLS Gen2 storage and Access Connector that Unity
# Catalog uses. One clean `terraform apply` — no Databricks provider needed.
#
# Premium tier + Unity Catalog + serverless + Genie are the Lakewatch prereqs.
# New Azure workspaces are Unity Catalog-enabled automatically, so UC comes on
# with this workspace (confirm the metastore in the account console — see README).
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Networking: VNet injection with two delegated subnets + an NSG.
# Databricks provisions the required NSG rules automatically ("AllRules").
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_network_security_group" "this" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

locals {
  subnet_delegation_actions = [
    "Microsoft.Network/virtualNetworks/subnets/join/action",
    "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
    "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
  ]
}

resource "azurerm_subnet" "public" {
  name                 = "${var.prefix}-public"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.public_subnet_cidr]

  delegation {
    name = "databricks-public"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = local.subnet_delegation_actions
    }
  }
}

resource "azurerm_subnet" "private" {
  name                 = "${var.prefix}-private"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_subnet_cidr]

  delegation {
    name = "databricks-private"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = local.subnet_delegation_actions
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# ---------------------------------------------------------------------------
# ADLS Gen2 storage — the landing zone for security telemetry.
# Hierarchical namespace (is_hns_enabled) is required for Unity Catalog.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "telemetry" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type # LRS if your region has no ZRS
  is_hns_enabled           = true
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "security" {
  name               = "security"
  storage_account_id = azurerm_storage_account.telemetry.id
}

# ---------------------------------------------------------------------------
# Access Connector — the managed identity Unity Catalog uses to reach storage.
# Consumed by the Stage 2 storage credential.
# ---------------------------------------------------------------------------
resource "azurerm_databricks_access_connector" "uc" {
  name                = "${var.prefix}-uc-connector"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "uc_storage" {
  scope                = azurerm_storage_account.telemetry.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.uc.identity[0].principal_id
}

# ---------------------------------------------------------------------------
# Azure Databricks workspace — Premium, VNet-injected, no public IP (SCC).
# ---------------------------------------------------------------------------
resource "azurerm_databricks_workspace" "this" {
  name                        = var.workspace_name
  resource_group_name         = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  sku                         = "premium" # required for Unity Catalog + security features
  managed_resource_group_name = "${var.prefix}-managed-rg"

  # Keep public access on so the workspace UI/API is reachable without Private Link.
  # For full lockdown, set public_network_access_enabled = false AND add front-end +
  # back-end Private Link endpoints with private DNS (out of scope for this baseline).
  public_network_access_enabled         = var.public_network_access_enabled
  network_security_group_rules_required = var.public_network_access_enabled ? null : "NoAzureDatabricksRules"

  custom_parameters {
    no_public_ip                                        = true # secure cluster connectivity
    virtual_network_id                                  = azurerm_virtual_network.this.id
    public_subnet_name                                  = azurerm_subnet.public.name
    private_subnet_name                                 = azurerm_subnet.private.name
    public_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private.id
  }

  tags = var.tags

  depends_on = [
    azurerm_subnet_network_security_group_association.public,
    azurerm_subnet_network_security_group_association.private,
  ]
}
