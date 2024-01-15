
resource "azurerm_purview_account" "purview-vnet" {
  name                = var.purview_Name #"pv-cg-dev-ae-006"
  count = var.purview_Enable == true && var.VNET_Enable == true ? 1:0
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location

  identity {
    type = "SystemAssigned"
  }
}