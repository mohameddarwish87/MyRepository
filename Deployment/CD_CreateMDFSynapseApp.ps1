if($env:Synapse_Enable -eq "True" -and $env:VNET_Enable -eq "False")
{
    $Synapse = Test-AzSynapseWorkspace -Name $env:Synapse_Name -ResourceGroupName $env:ResouceGroup_Name
    if ($Synapse -eq $False) 
    {
        Write-Host "Creating Azure Synapse..."
        $secret =  Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_Synapse_DBPassword -AsPlainText
        $tenant =  Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_TenantId -AsPlainText
        New-AzResourceGroupDeployment -ResourceGroupName $env:ResouceGroup_Name `
        -TemplateFile .\Deployment\arm\06-Synapse5.json `
        -workspaces_intergen_data_mdp_synapse_dev_name $env:Synapse_Name `
        -storage_account_name $env:StorageAccount_Name `
        -Synapse_SqlAdministratorLogin $env:Synapse_SqlAdministratorLogin `
        -Synapse_SqlAdministratorPassword $secret `
        -spark_pool_name $env:Synapse_PoolName `
        -spark_pool_shutdown_time $env:Synapse_ShutDown_Time `
        -tenantId $tenant `
        -Synapse_managed_resource_group $env:Synapse_ManagedResourceGroup `
        -KeyVault_Name $env:KeyVault_Name -Verbose
    }
    else 
    {
        Write-Host "$env:Synapse_Name exists"
        
    }
}

