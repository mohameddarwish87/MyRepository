
resource "null_resource" "GrantRBAC_VNET" {
  #count = var.Synapse_Enable == true && var.StorageAccount_Enable == true && var.VNET_Enable == true ? 1:0
  count = var.RBAC_Enable == true && var.VNET_Enable == true? 1:0
    provisioner "local-exec" {
      command = <<-EOT
      Write-Host "Start RBAC"
      $SP_CLIENT_ID= "f2df94b0-08a8-4884-9583-9d50bb365f4b"
      $SP_CLIENT_SECRET= "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk"
      $SP_TENANT_ID = "4cda32ca-6b19-4051-8b93-85889e7947dd"
      az login --service-principal -u $SP_CLIENT_ID -p $SP_CLIENT_SECRET --tenant $SP_TENANT_ID
      az config set extension.use_dynamic_install=yes_without_prompt
      $subid = (az account show -s "${var.Subscription_Name}" | ConvertFrom-Json).id
      $basescope = "/subscriptions/$subid/resourceGroups/${azurerm_resource_group.resourcegroup.name}/providers"
          
          $AzureFunctionId = ((az webapp identity show --resource-group ${azurerm_resource_group.resourcegroup.name} --name ${var.FunctionApp_Name}) | ConvertFrom-Json).principalId
          $AzureSynapseId = (Get-AzSynapseWorkspace -ResourceGroupName ${azurerm_resource_group.resourcegroup.name} -Name ${var.Synapse_Name}).Identity.PrincipalId
          $LeadDevID = "010bc095-7af8-4b59-a3ba-7aa5d9765af1" #$env:LeadDevID #your AAD objectID
          
          if ($null -eq  $AzureFunctionId)
          {
              Write-Host "Creating System managed identity for function app.."
              az webapp identity assign -g ${azurerm_resource_group.resourcegroup.name} -n ${var.FunctionApp_Name}
              $AzureFunctionId = ((az webapp identity show --resource-group ${azurerm_resource_group.resourcegroup.name} --name ${var.FunctionApp_Name}) | ConvertFrom-Json).principalId
          }
          Write-Host "Assigning MSI Access from AF to ADLS Gen2.."
          az role assignment create --assignee-object-id $AzureFunctionId --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/${var.StorageAccount_Name}"
          Write-Host "Assigning get and list access for azure function to Key Vault.."
          az keyvault set-policy --name ${var.KeyVault_Name} --object-id $AzureFunctionId --certificate-permissions get list --key-permissions get list --resource-group ${azurerm_resource_group.resourcegroup.name} --secret-permissions get list --subscription $subid
          Write-Host "Assigning get and list access for Synapse to Key Vault.."
          az keyvault set-policy --name ${var.KeyVault_Name} --object-id $AzureSynapseId --certificate-permissions get list --key-permissions get list --resource-group ${azurerm_resource_group.resourcegroup.name} --secret-permissions get list --subscription $subid
          
          

        # Write-Host "Assigning SP as Storage Contributor of ADLS.." Not needed for the deployment SP
        # az role assignment create --assignee-object-id ${data.azurerm_client_config.current.object_id} --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/${var.StorageAccount_Name}"
        
          
          #Write-Host "Assigning SP as contributor of Synapse"  Not needed - it inherits owner when SP creates the workspace.
          #az role assignment create --assignee-object-id ${data.azurerm_client_config.current.object_id} --assignee-principal-type "ServicePrincipal" --role "Contributor" --scope "$basescope/Microsoft.Synapse/workspaces/${var.Synapse_Name}"




      #  Grant the Service Principal Synapse Admin so it can set RBAC.

          Write-Host "Adding Service Principal as Synapse admin in Synapse.."
          az synapse role assignment create --workspace-name ${var.Synapse_Name} --role "Synapse Administrator" --assignee-object-id ${data.azurerm_client_config.current.object_id} --assignee-principal-type "ServicePrincipal" --subscription $subid
      

          Write-Host "Adding AF as Synapse compute operator in Synapse.." #TB - 2023-04-28 Synapse compute operator is the minimum permissions for the function app to schedule batch jobs. Reduced Synapse admin to this.
          az synapse role assignment create --workspace-name ${var.Synapse_Name} --role "Synapse Compute Operator" --assignee-object-id $AzureFunctionId --assignee-principal-type "ServicePrincipal" --subscription $subid

          Write-Host "Adding the Lead Developer as a Synapse admin in Synapse"
          az synapse role assignment create --workspace-name ${var.Synapse_Name} --role "Synapse Administrator" --assignee-object-id $LeadDevID  --subscription ${azurerm_resource_group.resourcegroup.name}    #--assignee-principal-type "User"

          Write-Host "Adding the Lead Developer as the Synapse SQL administrator in Synapse"   
          Set-AzSynapseSqlActiveDirectoryAdministrator -WorkspaceName ${var.Synapse_Name} -ObjectId $LeadDevID

          Write-Host "Assigning get and list access for the Lead Dev to Key Vault.."
          az keyvault set-policy --name ${var.KeyVault_Name} --object-id $LeadDevID --resource-group ${azurerm_resource_group.resourcegroup.name} --secret-permissions get list set delete --subscription $subid
      EOT

      interpreter = ["PowerShell", "-Command"]
      }
  depends_on  = [
      azurerm_synapse_workspace.synapse_vnet[0],azurerm_storage_account.storage_vnet[0], azurerm_key_vault.KeyVault[0],
      azurerm_linux_function_app.FunctionApp_VNET[0]
  ]
}