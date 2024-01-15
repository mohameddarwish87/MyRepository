# "Creating new Managed Private Endpoint from Synapse to Azure function..."

# resource "azurerm_synapse_managed_private_endpoint" "synapse_mpe_func_vnet" {
#   name                 = "managedPrivateEndpointAzureFunction"
#   synapse_workspace_id = azurerm_synapse_workspace.synapse_vnet[0].id
#   target_resource_id   = azurerm_linux_function_app.FunctionApp_VNET[0].id
#   subresource_name     = "sites"

# }

# resource "azurerm_private_endpoint_connection" "function_app_connection" {
#   name                = "FunctionAppConnection"
#   resource_group_name = azurerm_resource_group.resourcegroup.name
#   #private_endpoint_id = azurerm_private_endpoint.func-pep-web.id
#   private_endpoint_id = azurerm_synapse_managed_private_endpoint.synapse_mpe_func_vnet.id

#   request_message = "Approve connection"
#   status          = "Approved"
# }


# resource "azurerm_synapse_managed_private_endpoint" "synapse_mpe_adls_vnet" {
#   name                 = "managedPrivateEndpointAdls"
#   synapse_workspace_id = azurerm_synapse_workspace.synapse_vnet[0].id
#   target_resource_id   = azurerm_storage_account.storage_vnet[0].id
#   subresource_name     = "blob"

  
# }

resource "null_resource" "CreateApproveSynapseFunctionConnection5" {
  count = var.Synapse_Enable == true && var.FunctionApp_CreateEnable == true && var.VNET_Enable == true ? 1:0

      provisioner "local-exec" {


      command = <<-EOT
      Write-Host "1"
      $SP_CLIENT_ID= "f2df94b0-08a8-4884-9583-9d50bb365f4b"
      $SP_CLIENT_SECRET= "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk"
      $SP_TENANT_ID = "4cda32ca-6b19-4051-8b93-85889e7947dd"
      Write-Host "2"
      $azurePassword = ConvertTo-SecureString $SP_CLIENT_SECRET -AsPlainText -Force
      Write-Host "3"
      $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SP_CLIENT_ID, $azurePassword
      Write-Host "4"
      Connect-AzAccount -ServicePrincipal -TenantId $SP_TENANT_ID -Credential $Credential
      Write-Host "5"
      $FunctionApp = Get-AzFunctionApp -ResourceGroupName "${azurerm_resource_group.resourcegroup.name}" -Name "${azurerm_linux_function_app.FunctionApp_VNET[0].name}"
      $FunctionAppId = $FunctionApp.Id
      Write-Host "creating the PrivateEndpoint Definition Json file...."
      $jsonpath = "createprivateendpoint.json"
      $synapseWorkspaceVar = "${azurerm_synapse_workspace.synapse_vnet[0].name}"
      Write-Host "6"
      
      Write-Host "7"
      $createPrivateEndpointJsonString = @"
      {
          "properties": {
              "privateLinkResourceId": "$FunctionAppId",
              "groupId": "sites"
          }
      }
      "@      
      $jsonpath = ".\createprivateendpoint.json"
      Set-Content -Path $jsonpath -value $createPrivateEndpointJsonString
      Write-Host "Creating new Managed Private Endpoint from Synapse to Azure function..."
      New-AzSynapseManagedPrivateEndpoint -WorkspaceName $synapseWorkspaceVar -Name "managedPrivateEndpointAzureFunction" -DefinitionFile $jsonpath
      Write-Host "8"

      #$FunctionApp = Get-AzFunctionApp -ResourceGroupName "${azurerm_resource_group.resourcegroup.name}" -Name "${azurerm_linux_function_app.FunctionApp_VNET[0].name}"
      Write-Host "Function App is $FunctionApp"
      #$FunctionAppId = $FunctionApp.Id
      Write-Host "Function App id is $FunctionAppId"
      $FunctionApp_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $FunctionAppId | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
      Write-Host "9"
      Write-Host "Function App EPC is $FunctionApp_epc"
      Write-Host "Waiting for 90 seconds"
      sleep 90
      $FunctionApp_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $FunctionAppId | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
      Write-Host "Function App EPC is $FunctionApp_epc"
      if($FunctionApp_epc)
      {
      Write-Host "Approve managed private end point connection from Synapse to the Azure functions"
      Approve-AzPrivateEndpointConnection -ResourceId $FunctionApp_epc.Id
      Write-Host "10"
      }

      EOT

      interpreter = ["PowerShell", "-Command"]
      }
  depends_on  = [
      azurerm_linux_function_app.FunctionApp_VNET[0],azurerm_synapse_workspace.synapse_vnet[0] #, azurerm_key_vault_access_policy.kv_policy
  ]
}

resource "null_resource" "CreateApproveSynapseAdlsConnection5" {
  count = var.Synapse_Enable == true && var.StorageAccount_Enable == true && var.VNET_Enable == true ? 1:0
  

      provisioner "local-exec" {


      command = <<-EOT
      Write-Host "11"
      $SP_CLIENT_ID= "f2df94b0-08a8-4884-9583-9d50bb365f4b"
      $SP_CLIENT_SECRET= "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk"
      $SP_TENANT_ID = "4cda32ca-6b19-4051-8b93-85889e7947dd"
      $azurePassword = ConvertTo-SecureString $SP_CLIENT_SECRET -AsPlainText -Force
      Write-Host "12"
      $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SP_CLIENT_ID, $azurePassword
      Write-Host "13"
      Connect-AzAccount -ServicePrincipal -TenantId $SP_TENANT_ID -Credential $Credential
      Write-Host "14"
      $jsonpath = "createprivateendpoint.json"

      $synapseWorkspaceVar = "${azurerm_synapse_workspace.synapse_vnet[0].name}"
      Write-Host "15"
      $StoragePrivateLinkResource = Get-AzStorageAccount -ResourceGroupName "${azurerm_resource_group.resourcegroup.name}" -Name "${azurerm_storage_account.storage_vnet[0].name}"
      Write-Host "16"
      $StoragePrivateLinkResourceId = $StoragePrivateLinkResource.Id
      $createPrivateEndpointJsonString = @"
      {
          "properties": {
              "privateLinkResourceId": "$StoragePrivateLinkResourceId",
              "groupId": "dfs"
          }
      }
      "@      
      $jsonpath = ".\createprivateendpoint.json"
      Set-Content -Path $jsonpath -value $createPrivateEndpointJsonString
      Write-Host "Creating new Managed Private Endpoint from Synapse to blob storage account..."
      New-AzSynapseManagedPrivateEndpoint -WorkspaceName $synapseWorkspaceVar -Name "${azurerm_storage_account.storage_vnet[0].name}-blob" -DefinitionFile $jsonpath
      Write-Host "Waiting for 90 seconds"
      sleep 90

      Write-Host "17"
      $StorageAcc_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $StoragePrivateLinkResourceId | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
      Write-Host "18"
      if($StorageAcc_epc)
      {
      Write-Host "Storage Account EPC is $StorageAcc_epc"
      Write-Host "Approve managed private end point connection from Synapse to the blob storage account"
      Approve-AzPrivateEndpointConnection -ResourceId $StorageAcc_epc.Id
      Write-Host "19"
      }

      EOT

      interpreter = ["PowerShell", "-Command"]
      }
  depends_on  = [
      azurerm_synapse_workspace.synapse_vnet[0],azurerm_storage_account.storage_vnet[0]  #, azurerm_key_vault_access_policy.kv_policy
  ]
}
# resource "azurerm_private_endpoint_connection" "adls_connection" {
#   name                = "AdlsConnection"
#   resource_group_name = azurerm_resource_group.resourcegroup.name
#   #private_endpoint_id = azurerm_private_endpoint.func-pep-web.id
#   private_endpoint_id = azurerm_synapse_managed_private_endpoint.synapse_mpe_adls_vnet.id

#   request_message = "Approve connection"
#   status          = "Approved"
# }