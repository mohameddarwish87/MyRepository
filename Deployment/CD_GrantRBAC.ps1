

if ($env:Grant_RBAC_Enable -eq "True")
{
    Write-Host "Start RBAC"
az login --service-principal -u ${env:SP_CLIENT_ID} -p ${env:SP_CLIENT_SECRET} --tenant ${env:SP_TENANT_ID}
az config set extension.use_dynamic_install=yes_without_prompt
$subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
$basescope = "/subscriptions/$subid/resourceGroups/$env:ResouceGroup_Name/providers"
$basescope1 = "/subscriptions/$subid/resourceGroups/$env:ResouceGroup_Name"
    
    $AzureFunctionId = ((az webapp identity show --resource-group $env:ResouceGroup_Name --name $env:FunctionApp_Name) | ConvertFrom-Json).principalId

    if ($null -eq  $AzureFunctionId)
    {
        Write-Host "Creating System managed identity for function app.."
        az webapp identity assign -g $env:ResouceGroup_Name -n $env:FunctionApp_Name
        $AzureFunctionId = ((az webapp identity show --resource-group $env:ResouceGroup_Name --name $env:FunctionApp_Name) | ConvertFrom-Json).principalId
    }
    Write-Host "Assigning MSI Access from AF to ADLS Gen2.."
    az role assignment create --assignee-object-id $AzureFunctionId --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:StorageAccount_Name"
    Write-Host "Assigning get and list access for azure function to Key Vault.."
    #az keyvault set-policy --name $env:KeyVault_Name --object-id "b4b54d26-5a9e-4686-8ba1-dbff7d8de4cf" --certificate-permissions get list --key-permissions get list --resource-group $env:ResouceGroup_Name --secret-permissions get list --subscription $subid
    az keyvault set-policy --name $env:KeyVault_Name --object-id $AzureFunctionId --certificate-permissions get list --key-permissions get list --resource-group $env:ResouceGroup_Name --secret-permissions get list --subscription $subid
    Write-Host "Assigning MSI Access from AF to Synapse.."
    az role assignment create --assignee-object-id $AzureFunctionId --assignee-principal-type "ServicePrincipal" --role "Contributor" --scope "$basescope/Microsoft.Synapse/workspaces/$env:Synapse_Name"
    Write-Host "Assigning SP as Storage Contributor of ADLS.."
    az role assignment create --assignee-object-id ${env:SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:StorageAccount_Name"
    #az role assignment create --assignee-object-id "b4b54d26-5a9e-4686-8ba1-dbff7d8de4cf" --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:StorageAccount_Name"
    Write-Host "Assigning SP as Owner of Synapse.."
    az role assignment create --assignee-object-id ${env:SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Owner" --scope "$basescope/Microsoft.Synapse/workspaces/$env:Synapse_Name"
    #sleep 60
    #$azurePassword = ConvertTo-SecureString ${env:SP_CLIENT_SECRET} -AsPlainText -Force
    #$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ${env:SP_CLIENT_ID}, $azurePassword
    #Connect-AzAccount -ServicePrincipal -TenantId ${env:SP_TENANT_ID} -Credential $Credential
    Write-Host "Adding Service Principal as Synapse admin in Synapse.."
    az synapse role assignment create --workspace-name $env:Synapse_Name --role "Synapse Administrator" --assignee-object-id ${env:SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --subscription $env:ResourceGroup_Subscription
    #New-AzSynapseRoleAssignment -WorkspaceName $env:Synapse_Name -RoleDefinitionName "Synapse Administrator" -ObjectId $env:SP_OBJECT_ID


    Write-Host "Adding AF as Synapse admin in Synapse.."
    #Set-AzSynapseSqlActiveDirectoryAdministrator -WorkspaceName $env:Synapse_Name -ObjectId $AzureFunctionId 
    az synapse role assignment create --workspace-name $env:Synapse_Name --role "Synapse Administrator" --assignee-object-id $AzureFunctionId --assignee-principal-type "ServicePrincipal" --subscription $env:ResourceGroup_Subscription
    #New-AzSynapseRoleAssignment -WorkspaceName $env:Synapse_Name -RoleDefinitionName "Synapse Administrator" -ObjectId $AzureFunctionId

    Write-Host "Assigning MSI Access from Synapse to ADLS Gen2"
    $AzureSynapseId = (Get-AzSynapseWorkspace -ResourceGroupName $env:ResouceGroup_Name -Name $env:Synapse_Name).Identity.PrincipalId
    az role assignment create --assignee-object-id $AzureSynapseId --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:StorageAccount_Name"
    if ($null -ne  ${env:AAD_Group_Admin_ID})
    {
        Write-Host "Assigning AAD group admin  as contributor of Resource Group.."
        az role assignment create --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --role "Contributor" --scope $basescope1
        Write-Host "Assigning AAD group admin as Synapse Administrator of Synapse.."
        az synapse role assignment create --workspace-name $env:Synapse_Name --role "Synapse Administrator" --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --subscription $env:ResourceGroup_Subscription
        #New-AzSynapseRoleAssignment -WorkspaceName $env:Synapse_Name -RoleDefinitionName "Synapse Administrator" -ObjectId env:AAD_Group_Admin_ID
        Write-Host "Assigning AAD group admin  as Storage Contributor of storage account.."
        az role assignment create --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:StorageAccount_Name"
    
    
    }

}