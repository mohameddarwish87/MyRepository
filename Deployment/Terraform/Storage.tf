# This file we create the storage accounts, containers, upload converttodelta.py to system container
# we also add admin objects ids as storage blob data contributor to the storage account

# Below we create the storage account based on condition StorageAccount_Enable
resource "azurerm_storage_account" "storage" {
  name                     = var.StorageAccount_Name
  #resource_group_name      = azurerm_resource_group.example.name
  count = var.StorageAccount_Enable == true && var.VNET_Enable == false? 1 : 0
  resource_group_name      = azurerm_resource_group.resourcegroup.name
  location                 = azurerm_resource_group.resourcegroup.location
  account_tier             = "Standard"
  account_replication_type = var.StorageAccount_Terraform_SKU
  is_hns_enabled = var.StorageAccount_HierarchyEnable
  tags = var.tags
}

# Below we create the 5 containers listed in the container_names local variable based on condition StorageAccount_Enable
resource "azurerm_storage_container" "storage_container" {
  #for_each              = toset(local.container_names)
  for_each     = var.StorageAccount_Enable == true && var.VNET_Enable == false? toset(local.container_names) : []
  name                  = each.key
  storage_account_name  = azurerm_storage_account.storage[0].name
  container_access_type = "private"
}


# Below we run powershell script to upload converttodelta.py from azure devops repo to the system container
resource "null_resource" "uploadfile" {
  count = var.StorageAccount_Enable == true && var.VNET_Enable == false? 1 : 0

      provisioner "local-exec" {


      command = <<-EOT
      $azurePassword = ConvertTo-SecureString "${local.SP_CLIENT_SECRET}" -AsPlainText -Force
      $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "${local.SP_CLIENT_ID}", $azurePassword
      Connect-AzAccount -ServicePrincipal -TenantId "${local.SP_TENANT_ID}" -Credential $Credential
      $storageAcct = Get-AzStorageAccount -ResourceGroupName "${azurerm_resource_group.resourcegroup.name}" -Name "${azurerm_storage_account.storage[0].name}"
      $destPath = "${local.dirname}" + (Get-Item "${local.localSrcFile}").Name
      New-AzDataLakeGen2Item -Context $storageAcct.Context -FileSystem "${local.filesystemName}" -Path $destPath -Source "${local.localSrcFile}" -Force 

      EOT

      interpreter = ["PowerShell", "-Command"]
      }

}