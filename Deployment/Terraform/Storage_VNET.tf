# This file we create the storage accounts, containers, upload converttodelta.py to system container
# we also add admin objects ids as storage blob data contributor to the storage account

# Below we create the storage account based on condition StorageAccount_Enable
resource "azurerm_storage_account" "storage_vnet" {
  name                     = var.StorageAccount_Name
  #resource_group_name      = azurerm_resource_group.example.name
  count = var.StorageAccount_Enable == true && var.VNET_Enable == true? 1 : 0
  resource_group_name      = azurerm_resource_group.resourcegroup.name
  location                 = azurerm_resource_group.resourcegroup.location
  account_tier             = "Standard"
  account_replication_type = var.StorageAccount_Terraform_SKU
  is_hns_enabled = var.StorageAccount_HierarchyEnable
  tags = var.tags
}

# Below we create the 5 containers listed in the container_names local variable based on condition StorageAccount_Enable
resource "azurerm_storage_container" "storage_container_vnet" {
  #for_each              = toset(local.container_names)
  for_each     = var.StorageAccount_Enable == true && var.VNET_Enable == true? toset(local.container_names) : []
  name                  = each.key
  storage_account_name  = azurerm_storage_account.storage_vnet[0].name
  container_access_type = "private"
}


# Below we run powershell script to upload converttodelta.py from azure devops repo to the system container
resource "null_resource" "uploadfile_vnet" {
  count = var.StorageAccount_Enable == true && var.VNET_Enable == true? 1 : 0

      provisioner "local-exec" {


      command = <<-EOT
      $azurePassword = ConvertTo-SecureString "${local.SP_CLIENT_SECRET}" -AsPlainText -Force
      $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "${local.SP_CLIENT_ID}", $azurePassword
      Connect-AzAccount -ServicePrincipal -TenantId "${local.SP_TENANT_ID}" -Credential $Credential
      $storageAcct = Get-AzStorageAccount -ResourceGroupName "${azurerm_resource_group.resourcegroup.name}" -Name "${azurerm_storage_account.storage_vnet[0].name}"
      $destPath = "${local.dirname}" + (Get-Item "${local.localSrcFile}").Name
      New-AzDataLakeGen2Item -Context $storageAcct.Context -FileSystem "${local.filesystemName}" -Path $destPath -Source "${local.localSrcFile}" -Force 

      EOT

      interpreter = ["PowerShell", "-Command"]
      }

}
###1##############################################################################################################################
resource "azurerm_private_endpoint" "adls-pep-blob" {
  name                = "${var.StorageAccount_Name}-pepblob"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  subnet_id           = azurerm_subnet.DefaultSubnet.id

  private_service_connection {
    name                           = "${var.StorageAccount_Name}-pepcblob"
    private_connection_resource_id = azurerm_storage_account.storage_vnet[0].id
    subresource_names              = ["blob"]
    is_manual_connection = false
  }
  private_dns_zone_group {
    name                 = "${var.StorageAccount_Name}-zgblob"
    private_dns_zone_ids = [azurerm_private_dns_zone.adls-dnszone-blob.id]
  }
}

resource "azurerm_private_dns_zone" "adls-dnszone-blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}



resource "azurerm_private_dns_zone_virtual_network_link" "adls-vl-blob" {
 name                  = "${var.StorageAccount_Name}-vlblob"
 resource_group_name   = azurerm_resource_group.resourcegroup.name
 private_dns_zone_name = azurerm_private_dns_zone.adls-dnszone-blob.name
 virtual_network_id    = azurerm_virtual_network.VNET[0].id
}


resource "azurerm_network_interface" "adls-nic-blob" {
  name                = "${var.StorageAccount_Name}-nic-blob"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location

  ip_configuration {
    name                          = "${var.StorageAccount_Name}-ipconfig"
    subnet_id                     = azurerm_subnet.DefaultSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
###2##############################################################################################################################

resource "azurerm_private_endpoint" "adls-pep-dfs" {
  name                = "${var.StorageAccount_Name}-pepdfs"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  subnet_id           = azurerm_subnet.DefaultSubnet.id

  private_service_connection {
    name                           = "${var.StorageAccount_Name}-pepcdfs"
    private_connection_resource_id = azurerm_storage_account.storage_vnet[0].id
    subresource_names              = ["dfs"]
    is_manual_connection = false
  }
  private_dns_zone_group {
    name                 = "${var.StorageAccount_Name}-zgdfs"
    private_dns_zone_ids = [azurerm_private_dns_zone.adls-dnszone-dfs.id]
  }
}

resource "azurerm_private_dns_zone" "adls-dnszone-dfs" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}


resource "azurerm_private_dns_zone_virtual_network_link" "adls-vl-dfs" {
 name                  = "${var.StorageAccount_Name}-vldfs"
 resource_group_name   = azurerm_resource_group.resourcegroup.name
 private_dns_zone_name = azurerm_private_dns_zone.adls-dnszone-dfs.name
 virtual_network_id    = azurerm_virtual_network.VNET[0].id
}

resource "azurerm_network_interface" "adls-nic-dfs" {
  name                = "${var.StorageAccount_Name}-nic-dfs"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location

  ip_configuration {
    name                          = "${var.StorageAccount_Name}-ipconfig"
    subnet_id                     = azurerm_subnet.DefaultSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
###3##############################################################################################################################

resource "azurerm_private_endpoint" "adls-pep-file" {
  name                = "${var.StorageAccount_Name}-pepfile"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  subnet_id           = azurerm_subnet.DefaultSubnet.id

  private_service_connection {
    name                           = "${var.StorageAccount_Name}-pepcfile"
    private_connection_resource_id = azurerm_storage_account.storage_vnet[0].id
    subresource_names              = ["file"]
    is_manual_connection = false
  }
  private_dns_zone_group {
    name                 = "${var.StorageAccount_Name}-zgfile"
    private_dns_zone_ids = [azurerm_private_dns_zone.adls-dnszone-file.id]
  }
}

resource "azurerm_private_dns_zone" "adls-dnszone-file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}


resource "azurerm_private_dns_zone_virtual_network_link" "adls-vl-file" {
 name                  = "${var.StorageAccount_Name}-vlfile"
 resource_group_name   = azurerm_resource_group.resourcegroup.name
 private_dns_zone_name = azurerm_private_dns_zone.adls-dnszone-file.name
 virtual_network_id    = azurerm_virtual_network.VNET[0].id
}

resource "azurerm_network_interface" "adls-nic-file" {
  name                = "${var.StorageAccount_Name}-nic-file"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location

  ip_configuration {
    name                          = "${var.StorageAccount_Name}-ipconfig"
    subnet_id                     = azurerm_subnet.DefaultSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
