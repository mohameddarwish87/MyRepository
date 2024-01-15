Write-Host "Inside CD_CreateMDFFunctionApp_VNET.ps1"
if($env:FunctionApp_CreateEnable -eq "True" -and $env:VNET_Enable -eq "True")
{ 
    Write-Host "A"
    $FunctionApp = Get-AzFunctionApp -ResourceGroupName $env:ResouceGroup_Name -Name $env:FunctionApp_Name
    if ($null -eq $FunctionApp) 
    {
        Write-Host "B"
        $vnet_name = $env:VNET_Name 
        $vnetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $vnet_name 
        $vsubnet = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $env:default_Subnet_Name}
        $Function_Inbound = "$env:FunctionApp_Name-Inbound"
        #Write-Host "Create the Function Inbound subnet to the VNET"
        #Add-AzVirtualNetworkSubnetConfig -Name $Function_Inbound -VirtualNetwork $vnetwork -AddressPrefix 10.2.5.0/24 | Set-AzVirtualNetwork
       Write-Host "Creating Function Outbound for VNET Integration..."
        # = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $Function_Inbound}
        $Function_Outbound = $env:Functionapp_OutboundSubnet_Name#"$env:FunctionApp_Name-Outbound"
        #$functionappsubnetConfig = New-AzVirtualNetworkSubnetConfig -Name $Function_Outbound -AddressPrefix 10.2.0.0/24 -Delegation "Microsoft.Web/serverFarms"
        Write-Host "Create the Delegation for subnet"
        $delegation = New-AzDelegation -Name "ServerFarms_Delegation2" -ServiceName "Microsoft.Web/serverFarms"
        Write-Host "Create the Function Outbound subnet to the VNET"
      #  Add-AzVirtualNetworkSubnetConfig -Name $Function_Outbound -VirtualNetwork $vnetwork -AddressPrefix $env:Functionapp_OutboundSubnet -Delegation $delegation | Set-AzVirtualNetwork
        Write-Host "Creating Azure Function inside VNET..."
        New-AzResourceGroupDeployment `
        -ResourceGroupName $env:ResouceGroup_Name -TemplateFile .\Deployment\arm\'02-FunctionApp7-VNET3.json' `
        -appName $env:FunctionApp_Name `
        -StorageAccount_LandingContainer $env:StorageAccount_LandingContainer `
        -StorageAccount_RawContainer $env:StorageAccount_RawContainer `
        -StorageAccount_StagingContainer $env:StorageAccount_StagingContainer `
        -StorageAccount_CuratedContainer $env:StorageAccount_CuratedContainer `
        -StorageAccount_Name $env:StorageAccount_Name `
        -Synapse_Name $env:Synapse_Name `
        -Synapse_PoolName $env:Synapse_PoolName `
        -FunctionOutbound $Function_Outbound `
        -VNETId $vnetwork.Id `
        -runtime "python"
        #-vnetName $vnet_name       
    }
    else
    {
        Write-Host "$env:FunctionApp_Name exists"
    }
}
 