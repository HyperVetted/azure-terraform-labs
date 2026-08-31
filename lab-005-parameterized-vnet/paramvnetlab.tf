data "azurerm_resource_group" "existing" {
  name = var.rg_name
}

resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  address_space       = var.vnet_address_space
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "web" {
  name                 = local.web_snet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.web_cidr
}

resource "azurerm_subnet" "app" {
  name                 = local.app_snet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.app_cidr
}

resource "azurerm_subnet" "mgmt" {
  name                 = local.mgmt_snet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.mgmt_cidr
}
