# This file creates Key Vault and add secrets to it

# Creation of Key Vault with condition if variable KeyVault_Enable set to true
# we give SP object id get, list and set to secrets
resource "azurerm_key_vault" "KeyVault_VNET" {
  name                        = var.KeyVault_Name
  count = var.KeyVault_Enable == true && var.VNET_Enable == true? 1:0
  location                    = azurerm_resource_group.resourcegroup.location
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  network_acls {
    default_action = "Deny"

    bypass = "AzureServices"
    ip_rules = []
    virtual_network_subnet_ids = [azurerm_subnet.DefaultSubnet.id]
  }

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

# resource "azurerm_private_endpoint_connection" "kv-pepc" {
#   name                = "${var.KeyVault_Name}-pep-connection"
#   resource_group_name = azurerm_resource_group.resourcegroup.name
#   private_endpoint_id = azurerm_private_endpoint.kv-pep.id
# }

resource "azurerm_private_endpoint" "kv-pep" {
  name                = "${var.KeyVault_Name}-pep"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  subnet_id           = azurerm_subnet.DefaultSubnet.id

  private_service_connection {
    name                           = "${var.KeyVault_Name}-pepc"
    private_connection_resource_id = azurerm_key_vault.KeyVault_VNET[0].id
    subresource_names              = ["vault"]
    is_manual_connection = false
  }
  private_dns_zone_group {
    name                 = "${var.KeyVault_Name}-zg"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv-dnszone.id]
  }
}

resource "azurerm_private_dns_zone" "kv-dnszone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

# resource "azurerm_private_dns_virtual_network_link" "kv-vl" {
#   name                  = "${var.KeyVault_Name}-vl"
#   resource_group_name   = azurerm_resource_group.resourcegroup.name
#   private_dns_zone_name = azurerm_private_dns_zone.kv-dnszone.name
#   virtual_network_id    = azurerm_virtual_network.VNET.id
# }

resource "azurerm_private_dns_zone_virtual_network_link" "kv-vl" {
 name                  = "${var.KeyVault_Name}-vl"
 resource_group_name   = azurerm_resource_group.resourcegroup.name
 private_dns_zone_name = azurerm_private_dns_zone.kv-dnszone.name
 virtual_network_id    = azurerm_virtual_network.VNET[0].id
}


resource "azurerm_network_interface" "kv-nic" {
  name                = "${var.KeyVault_Name}-nic"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location

  ip_configuration {
    name                          = "${var.KeyVault_Name}-ipconfig"
    subnet_id                     = azurerm_subnet.DefaultSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
/*
resource "azurerm_private_dns_a_record" "kv-dns-record" {
  for_each = azurerm_network_interface.kv-nic

  name                = "${each.key}-record"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  zone_name           = azurerm_private_dns_zone.kv-dnszone.name
  ttl                 = 600
  #records             = [azurerm_network_interface.kv-nic[each.key].ip_configuration[0].private_ip_address]
  records             = [azurerm_network_interface.kv-nic.ip_configuration[0].private_ip_address]

}
*/
# resource "azurerm_private_dns_zone_group" "example" {
#   name                = "${var.KeyVault_Name}-zg"
#   resource_group_name = var.resource_group_name
#   private_dns_zone_ids = [azurerm_private_dns_zone.kv-dnszone.id]
#   private_endpoint_ids = [azurerm_private_endpoint.kv-pep.id]
# }



# Below we add secrets to the Key vault. secrets are defined in as a map called secret_maps defined in variables.tf & demo.auto.tfvars
resource "azurerm_key_vault_secret" "KeyVault_Secrets_VNET" {
  count = var.KeyVault_Enable == true  && var.VNET_Enable == true? length(var.secret_maps) : 0
  name         = keys(var.secret_maps)[count.index]
  value        = values(var.secret_maps)[count.index]
  key_vault_id = azurerm_key_vault.KeyVault_VNET[0].id
  depends_on  = [
      azurerm_key_vault.KeyVault_VNET[0]#, azurerm_key_vault_access_policy.kv_policy
  ]

}


