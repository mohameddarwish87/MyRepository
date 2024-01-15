
#Write-Host "Running Deploy MDDF Function script..."
Write-Host "Inside CD_CreateMDFFunctionApp.ps1"
if($env:FunctionApp_CreateEnable -eq "True" -and $env:VNET_Enable -eq "False")
{ 
    Write-Host "A"
    $FunctionApp = Get-AzFunctionApp -ResourceGroupName $env:ResouceGroup_Name -Name $env:FunctionApp_Name
    if ($null -eq $FunctionApp) 
    {
        Write-Host "B"
        Write-Host "Creating Azure Function..."
        New-AzResourceGroupDeployment `
        -ResourceGroupName $env:ResouceGroup_Name -TemplateFile .\Deployment\arm\'02-FunctionApp7.json' `
        -appName $env:FunctionApp_Name `
        -KeyVault_Name $env:KeyVault_Name `
        -KeyVault_SP_ClientId $env:KeyVault_SP_ClientId `
        -KeyVault_SP_ClientSecret $env:KeyVault_SP_ClientSecret `
        -KeyVault_SP_TenantId $env:KeyVault_SP_TenantId `
        -StorageAccount_LandingContainer $env:StorageAccount_LandingContainer `
        -StorageAccount_RawContainer $env:StorageAccount_RawContainer `
        -StorageAccount_StagingContainer $env:StorageAccount_StagingContainer `
        -StorageAccount_CuratedContainer $env:StorageAccount_CuratedContainer `
        -StorageAccount_Name $env:StorageAccount_Name `
        -Synapse_Name $env:Synapse_Name `
        -Synapse_PoolName $env:Synapse_PoolName
    }
    else
    {
        Write-Host "$env:FunctionApp_Name exists"
    }
}
 