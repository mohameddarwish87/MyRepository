
if($env:KeyVault_Enable -eq "True" -and $env:VNET_Enable -eq "False")
{
    $SP_Object_ID = ${env:SP_Object_ID}
    $KeyVault = Get-AzKeyVault -VaultName $env:KeyVault_Name -ResourceGroupName $env:KeyVault_ResourceGroup -ErrorAction SilentlyContinue
    if($null -eq $KeyVault)
    {
        $KeyVault = Get-AzKeyVault -VaultName $env:KeyVault_Name -Location $env:ResourceGroup_Location -InRemovedState -ErrorAction SilentlyContinue
        if ($null -eq $KeyVault) 
        {
           
           Write-Host "Creating Azure Key Vault..."
           New-AzResourceGroupDeployment `
           -ResourceGroupName $env:KeyVault_ResourceGroup `
           -TemplateFile .\Deployment\arm\05-KeyVault.json `
           -keyVaultName $env:KeyVault_Name `
           -objectId $SP_Object_ID           
        }
        else 
        {
            Write-Host "$env:KeyVault_Name exists but is in soft-deleted state"
        }
    }
    else
    {
        Write-Host "$env:KeyVault_Name already exists"
    }
   Set-AzKeyVaultAccessPolicy -VaultName $env:KeyVault_Name -ObjectId $SP_Object_ID -PermissionsToSecrets Get,List,Set
    $SP_Client_ID = ConvertTo-SecureString ${env:SP_Client_ID} -AsPlainText -Force
    $SP_Object_ID = ConvertTo-SecureString ${env:SP_Object_ID} -AsPlainText -Force
    $SP_Client_Secret = ConvertTo-SecureString ${env:SP_Client_Secret} -AsPlainText -Force
    $SP_Tenant_ID = ConvertTo-SecureString ${env:SP_Tenant_ID} -AsPlainText -Force
    $Synapse_DBPassword = ConvertTo-SecureString ${env:Synapse_SqlAdministratorPassword_secret} -AsPlainText -Force
    $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_ObjectId   
}
##########################Adding Secrets in KV###########################################

$KeyVault = Get-AzKeyVault -VaultName $env:KeyVault_Name -ResourceGroupName $env:KeyVault_ResourceGroup -ErrorAction SilentlyContinue
if($null -eq $KeyVault)
{
    $KeyVault1 = Get-AzKeyVault -VaultName $env:KeyVault_Name -Location $env:ResourceGroup_Location -InRemovedState -ErrorAction SilentlyContinue
    if ($null -eq $KeyVault1) 
    {

        if ($env:KeyVault_AddSecret -eq "True") 
        {
            Write-Host "2"
            $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_ObjectId
            Write-Host "iii"
            if ($null -eq $KeyVaultSecret) 
            {
                Write-Host "Adding SP Object ID as a secret to the Key Vault..."
                Set-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_ObjectId -SecretValue $SP_Object_ID
            }
            $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_ClientId
            if ($null -eq $KeyVaultSecret) 
            {
                Write-Host "Adding SP Client ID as a secret to the Key Vault..."
                Set-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_ClientId -SecretValue $SP_Client_ID
            }
            $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_ClientSecret
            if ($null -eq $KeyVaultSecret) 
            {
                Write-Host "Adding SP Client Secret as a secret to the Key Vault..."
                Set-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_ClientSecret -SecretValue $SP_Client_Secret
            }
            $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_TenantId
            if ($null -eq $KeyVaultSecret) 
            {
                Write-Host "Adding SP Tenant ID as a secret to the Key Vault..."
                Set-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_TenantId -SecretValue $SP_Tenant_ID
            }    
            $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_Synapse_DBPassword
            if ($null -eq $KeyVaultSecret) 
            {
                Write-Host "Adding Synapse DB Password as a secret to the Key Vault..."
                Set-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_Synapse_DBPassword -SecretValue $Synapse_DBPassword
            }        

            $KeyVaultSecret = Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_VM_Password
            if ($null -eq $KeyVaultSecret) 
            {
                Write-Host "Adding VM Password as a secret to the Key Vault..."
                Set-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_VM_Password -SecretValue $VM_Password
            } 
        }           
#####################################################################
    }
    else 
    {
        Write-Host "$env:KeyVault_Name exists but is in soft-deleted state"
    }
}