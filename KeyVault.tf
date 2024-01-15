# This file creates Key Vault and add secrets to it

# Creation of Key Vault with condition if variable KeyVault_Enable set to true
# we give SP object id get, list and set to secrets
resource "azurerm_key_vault" "KeyVault" {
  name                        = var.KeyVault_Name
  count = var.KeyVault_Enable == true && var.VNET_Enable == false? 1:0
  location                    = azurerm_resource_group.resourcegroup.location
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "Get", "List", "Update"
    ]

    secret_permissions = [
      "Get", "List", "Set" ,"Purge"
    ]

    storage_permissions = [
      "Get", "List", "Set"
    ]
  }
}



# Below we add secrets to the Key vault. secrets are defined in as a map called secret_maps defined in variables.tf & demo.auto.tfvars
resource "azurerm_key_vault_secret" "KeyVault_Secrets" {
  count = var.KeyVault_Enable == true  && var.VNET_Enable == false? length(var.secret_maps) : 0
  name         = keys(var.secret_maps)[count.index]
  value        = values(var.secret_maps)[count.index]
  key_vault_id = azurerm_key_vault.KeyVault[0].id
  depends_on  = [
      azurerm_key_vault.KeyVault[0]#, azurerm_key_vault_access_policy.kv_policy
  ]

}


