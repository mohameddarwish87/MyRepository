# This file define and creates resource group
resource "azurerm_resource_group" "resourcegroup" {
  name     = var.ResouceGroup_Name
  #count = var.ResouceGroup_Enable == true ? 1:0
  location = var.ResourceGroup_Location
  tags = {Owner = "Mohamed Darwish", Project = "Metadata Driven Framework"}
  lifecycle { 

    prevent_destroy = true

  } 
  #tags = var.tags
}
