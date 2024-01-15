
resource "azurerm_data_share_account" "DataShare" {
  count = var.DataShare_Enable == true ? 1:0
  name                = var.DataShare_Name
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  identity {
    type = "SystemAssigned"
  }

  tags = {
    foo = "bar"
  }
}