if($env:StorageAccount_Enable -eq "True" -and $env:VNET_Enable -eq "False")
{
    $StorageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:StorageAccount_Name -ErrorAction SilentlyContinue
    if ($null -eq $StorageAccount) 
    {
        Write-Host "Creating Storage Account..."
        New-AzResourceGroupDeployment `
        -ResourceGroupName $env:ResouceGroup_Name `
        -TemplateFile .\Deployment\arm\01-Storage5.json `
        -storageAccountName $env:StorageAccount_Name `
        -storageSKU $env:StorageAccount_SKU `
        -IsHierarchyEnabled $env:StorageAccount_HierarchyEnable
    }
    else
    {
        Write-Host "$env:StorageAccount_Name exists"

    }
    
}
