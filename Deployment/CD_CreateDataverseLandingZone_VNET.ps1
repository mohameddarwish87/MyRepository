
#########################################################Storage Account Creation################################################
##if($env:StorageAccount_Enable -eq "True" -and $env:VNET_Enable -eq "True")
if($env:Dataverse_LandingZone_Create -eq "True")
{
#    Write-Host "Creating new Dataverse VNET..."
#    Write-Host "Configure the Dataverse back-end subnet..."     
#    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $env:Dataverse_Default_Subnet_Name -AddressPrefix $env:Dataverse_Default_Subnet_Address

#    Write-Host "Create the virtual network..."
#    $net = @{
#        Name = $env:Dataverse_VNET_Name
#        ResourceGroupName = $env:ResouceGroup_Name
#        Location = $env:Dataverse_LandingZone_Location
#        AddressPrefix = $env:Dataverse_VNET_AddressPrefix
#        Subnet = $subnetConfig
#    }
#    $vnet = New-AzVirtualNetwork @net
#    Write-Host "Adding KeyVault, Web and Storage as Service Point to Subnet.."
#    $SEP = @('Microsoft.KeyVault','Microsoft.Web','Microsoft.Storage')
#    foreach($mySEP in $SEP){
#    Write-Host "aa"
#    $virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $env:Dataverse_VNET_Name |  Get-AzVirtualNetworkSubnetConfig  -Name $env:Dataverse_Default_Subnet_Name 
#    Write-Host "bb"
#    $ServiceEndPoint = New-Object 'System.Collections.Generic.List[String]'
#    Write-Host "cc"
#    $VirtualNetwork.ServiceEndpoints | ForEach-Object { $ServiceEndPoint.Add($_.service)}
#    Write-Host "dd"
#    $ServiceEndPoint.Add($mySEP)
#    Write-Host "ee"
#    $virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $env:Dataverse_VNET_Name
#    Write-Host "ee1"
#    $virtualNetwork | Set-AzVirtualNetworkSubnetConfig -Name $env:Dataverse_Default_Subnet_Name   -AddressPrefix $env:Dataverse_Default_Subnet_Address -ServiceEndpoint $ServiceEndPoint
#    Write-Host "ff"
#    $virtualNetwork | Set-AzVirtualNetwork
#    Write-Host "gg"
#    }    
    $StorageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:Dataverse_StorageAccount_Name -ErrorAction SilentlyContinue
    $vnetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $env:Dataverse_VNET_Name  
    if ($null -eq $StorageAccount) 
    {
        Write-Host "Creating DataVerse Storage Account inside VNET..."
        New-AzResourceGroupDeployment `
        -ResourceGroupName $env:ResouceGroup_Name `
        -TemplateFile .\Deployment\arm\01-Storage5-VNET3.json `
        -storageAccountName $env:Dataverse_StorageAccount_Name `
        -storageSKU $env:StorageAccount_SKU `
        -IsHierarchyEnabled $env:StorageAccount_HierarchyEnable `
        -VNETId $vnetwork.Id `
        -location $env:Dataverse_LandingZone_Location `
        -StorageAccount_SubnetName $env:Dataverse_Default_Subnet_Name
        
        Write-Host "2"
        $vsubnet = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $env:Dataverse_Default_Subnet_Name}
        Write-Host "3"
        $storageacc = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:Dataverse_StorageAccount_Name
        Write-Host "4"
        $subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
        Write-Host "Creating private end point connection"
        #$privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "adls-blob-PEPC" -PrivateLinkServiceId $storageacc.Id -GroupId "blob"
        $privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "${env:Dataverse_StorageAccount_Name}-pepcblob" -PrivateLinkServiceId $storageacc.Id -GroupId "blob"
        Write-Host "5"
        Write-Host "Creating private end point"
        #$privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "adls-blob-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2
        $privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:Dataverse_StorageAccount_Name}-pepblob" -Location $env:Dataverse_LandingZone_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2
        Write-Host "6"
        #        Write-Host "Creating private DNS zone"
        #        $dnszone2 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.blob.core.windows.net"
        #        Write-Host "7"
        #        Write-Host "Creating private DNS virtual network link"
                #$vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.blob.core.windows.net" -Name "adls-blob-virtual-link" -VirtualNetworkId $vnetwork.Id
        #        $vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.blob.core.windows.net" -Name "${env:Dataverse_StorageAccount_Name}-vlblob" -VirtualNetworkId $vnetwork.Id
        Write-Host "8"
        $networkInterface2 = Get-AzResource -ResourceId $privateEndpoint2.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        #$networkInterface2 = Get-AzResource -ResourceId $privateEndpoint2.NetworkInterfaces[0] -ApiVersion "2019-04-01"
        Write-Host "9"

        foreach ($ipconfig in $networkInterface2.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
           Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating private DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.blob.core.windows.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }  
        #        $cg = @{
        #            Name = 'privatelink.blob.core.windows.net'
        #            PrivateDnsZoneId = $dnszone2.ResourceId
        #        }
        #        Write-Host "Creating private DNS zone config"
        #        $config = New-AzPrivateDnsZoneConfig @cg
                
                ## Create the DNS zone group. ##
        #        $zg = @{
        #            ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "adls-blob-PEP" 
        #            PrivateEndpointName = "${env:Dataverse_StorageAccount_Name}-pepblob"
                #Name = 'blobZoneGroup'
        #            Name = "${env:Dataverse_StorageAccount_Name}-zgblob"
        #            PrivateDnsZoneConfig = $config
        #        }
        #        Write-Host "Creating private DNS zone group"
        #        New-AzPrivateDnsZoneGroup @zg
       
        Write-Host "Creating private end point connection"
        $privateEndpointConn3 = New-AzPrivateLinkServiceConnection -Name "${env:Dataverse_StorageAccount_Name}-pepcdfs" -PrivateLinkServiceId $storageacc.Id -GroupId "dfs"
        Write-Host "10"
        Write-Host "Creating private end point"
        $privateEndpoint3 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:Dataverse_StorageAccount_Name}-pepdfs" -Location $env:Dataverse_LandingZone_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn3
        #Write-Host "11"
        #        Write-Host "Creating private DNS zone"
        #        $dnszone3 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.dfs.core.windows.net"
        #        Write-Host "12"
        #        Write-Host "Creating private DNS virtual network link"
                #$vlink3 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dfs.core.windows.net" -Name "adls-dfs-virtual-link" -VirtualNetworkId $vnetwork.Id
        #        $vlink3 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dfs.core.windows.net" -Name "${env:Dataverse_StorageAccount_Name}-vldfs" -VirtualNetworkId $vnetwork.Id
        Write-Host "13"
        $networkInterface3 = Get-AzResource -ResourceId $privateEndpoint3.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        Write-Host "14"
    
        foreach ($ipconfig in $networkInterface3.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
            Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating private DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.dfs.core.windows.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }
        #        $cg = @{
        #            Name = 'privatelink.dfs.core.windows.net'
        #            PrivateDnsZoneId = $dnszone3.ResourceId
        #        }
        #        Write-Host "Creating private DNS zone config"
        #        $config = New-AzPrivateDnsZoneConfig @cg
                
                ## Create the DNS zone group. ##
        #        $zg = @{
        #            ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "adls-dfs-PEP" 
        #            PrivateEndpointName = "${env:Dataverse_StorageAccount_Name}-pepdfs" 
                #Name = 'dfsZoneGroup'
        #            Name = "${env:Dataverse_StorageAccount_Name}-zgdfs"
        #            PrivateDnsZoneConfig = $config
        #        }    
        #        Write-Host "Creating private DNS zone group"
        #        New-AzPrivateDnsZoneGroup @zg

        Write-Host "Creating private end point connection"
        $privateEndpointConn4 = New-AzPrivateLinkServiceConnection -Name "${env:Dataverse_StorageAccount_Name}-pepcfile" -PrivateLinkServiceId $storageacc.Id -GroupId "file"
        Write-Host "15"
        Write-Host "Creating private end point"
        $privateEndpoint4 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:Dataverse_StorageAccount_Name}-pepfile" -Location $env:Dataverse_LandingZone_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn4
        Write-Host "16"
        #        Write-Host "Creating private DNS zone"
        #        $dnszone4 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.file.core.windows.net"
        #        Write-Host "17"
        #        Write-Host "Creating private DNS virtual network link"
                #$vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.file.core.windows.net" -Name "adls-file-virtual-link" -VirtualNetworkId $vnetwork.Id
        #        $vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.file.core.windows.net" -Name "${env:Dataverse_StorageAccount_Name}-vlfile" -VirtualNetworkId $vnetwork.Id
        $networkInterface4 = Get-AzResource -ResourceId $privateEndpoint4.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        Write-Host "19"
   
        foreach ($ipconfig in $networkInterface4.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
            Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating private DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.file.core.windows.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }
        #        $cg = @{
        #            Name = 'privatelink.file.core.windows.net'
        #            PrivateDnsZoneId = $dnszone4.ResourceId
        #        }
        #        Write-Host "Creating private DNS zone config"
        #        $config = New-AzPrivateDnsZoneConfig @cg
                
                ## Create the DNS zone group. ##
        #        $zg = @{
        #            ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "adls-file-PEP" 
        #            PrivateEndpointName = "${env:Dataverse_StorageAccount_Name}-pepfile"
                #Name = 'dfsZoneGroup'
        #            Name = "${env:Dataverse_StorageAccount_Name}-zgfile"
        #            PrivateDnsZoneConfig = $config
        #        }    
        #        Write-Host "Creating private DNS zone group"
        #        New-AzPrivateDnsZoneGroup @zg

        Remove-AzRmStorageContainer -ResourceGroupName $env:ResouceGroup_Name  -StorageAccountName $env:Dataverse_StorageAccount_Name -Name $env:StorageAccount_LandingContainer -Force
        Remove-AzRmStorageContainer -ResourceGroupName $env:ResouceGroup_Name  -StorageAccountName $env:Dataverse_StorageAccount_Name -Name $env:StorageAccount_RawContainer -Force
        Remove-AzRmStorageContainer -ResourceGroupName $env:ResouceGroup_Name  -StorageAccountName $env:Dataverse_StorageAccount_Name -Name $env:StorageAccount_StagingContainer -Force
        Remove-AzRmStorageContainer -ResourceGroupName $env:ResouceGroup_Name  -StorageAccountName $env:Dataverse_StorageAccount_Name -Name $env:StorageAccount_CuratedContainer -Force
       Remove-AzRmStorageContainer -ResourceGroupName $env:ResouceGroup_Name  -StorageAccountName $env:Dataverse_StorageAccount_Name -Name 'system' -Force

    }
    else
    {
        Write-Host "$env:Dataverse_StorageAccount_Name exists"

    }
    
}

#########################################################Synapse Creation#######################################################
if($env:Dataverse_LandingZone_Create -eq "True")
{
    #$Synapse = Test-AzSynapseWorkspace -Name $env:Synapse_Name -ResourceGroupName $env:ResouceGroup_Name
    $Synapse = Test-AzSynapseWorkspace -Name $env:Dataverse_Synapse_Name -ResourceGroupName $env:ResouceGroup_Name    
    if ($Synapse -eq $False) 
    {   
        Write-Host "Creating DataVerse Synapse inside VNET..."
        $secret =  Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_Synapse_DBPassword -AsPlainText
        $tenant =  Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_TenantId -AsPlainText
        New-AzResourceGroupDeployment -ResourceGroupName $env:ResouceGroup_Name `
        -TemplateFile .\Deployment\arm\06-Synapse-VNET4.json `
        -workspaces_intergen_data_mdp_synapse_dev_name $env:Dataverse_Synapse_Name `
        -storage_account_name $env:Dataverse_StorageAccount_Name `
        -Synapse_SqlAdministratorLogin $env:Synapse_SqlAdministratorLogin `
        -Synapse_SqlAdministratorPassword $secret `
        -spark_pool_name $env:Dataverse_Synapse_PoolName `
        -spark_pool_shutdown_time $env:Synapse_ShutDown_Time `
        -tenantId $tenant `
        -Synapse_managed_resource_group $env:Dataverse_Synapse_ManagedResourceGroup `
        -PrivateLinkHub $env:Dataverse_Synapse_PrivateLinkHub `
        -location $env:Dataverse_LandingZone_Location `
        -KeyVault_Name $env:KeyVault_Name 

       Write-Host "1"
        $vnetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $env:Dataverse_VNET_Name
        Write-Host "2"
        $vsubnet = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $env:Dataverse_Default_Subnet_Name}
        Write-Host "3"
        $azsynapse = Get-AzSynapseWorkspace -Name $env:Dataverse_Synapse_Name
        Write-Host "4"
        $subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
        $privatelinkhub = $env:Dataverse_Synapse_PrivateLinkHub
        $privatelinkhubid="/subscriptions/$subid/resourceGroups/$env:ResouceGroup_Name/providers/Microsoft.Synapse/privateLinkHubs/$privatelinkhub"
        Write-Host "Creating private end point connection"
        $privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "$env:Dataverse_Synapse_Name-pepcsql" -PrivateLinkServiceId $azsynapse.Id -GroupId "SQL"
        Write-Host "5"
        Write-Host "Creating private end point"
        $privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "$env:Dataverse_Synapse_Name-pepsql" -Location $env:Dataverse_LandingZone_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2 -Force
        #        Write-Host "Creating private DNS zone"
        #        $dnszone2 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.sql.azuresynapse.net"
        #        Write-Host "7"
        #        Write-Host "Creating private DNS virtual network link"
                #$vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.sql.azuresynapse.net" -Name "syn-sql-virtual-link" -VirtualNetworkId $vnetwork.Id
        #        $vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.sql.azuresynapse.net" -Name "$env:Dataverse_Synapse_Name-vlsql" -VirtualNetworkId $vnetwork.Id
        Write-Host "8"
        $networkInterface2 = Get-AzResource -ResourceId $privateEndpoint2.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        Write-Host "9"

        foreach ($ipconfig in $networkInterface2.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
            Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating private DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.sql.azuresynapse.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }   

        #        $cg = @{
        #            Name = "privatelink.sql.azuresynapse.net"
        #            PrivateDnsZoneId = $dnszone2.ResourceId
        #        }
        #        Write-Host "Creating private DNS zone config"
        #        $config = New-AzPrivateDnsZoneConfig @cg
                
                ## Create the DNS zone group. ##
        #        $zg = @{
        #            ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "Synapse-SQL-PEP" 
        #            PrivateEndpointName = "$env:Dataverse_Synapse_Name-pepsql"
                #Name = "SQLZoneGroup"
        #            Name = "$env:Dataverse_Synapse_Name-zgsql"
        #            PrivateDnsZoneConfig = $config
        #        }
        #        Write-Host "Creating private DNS zone group"
        #        New-AzPrivateDnsZoneGroup @zg 
        
        Write-Host "10"
        Write-Host "Creating private end point connection"
        $privateEndpointConn3 = New-AzPrivateLinkServiceConnection -Name "$env:Dataverse_Synapse_Name-pepcsqlod" -PrivateLinkServiceId $azsynapse.Id -GroupId "SqlOnDemand"
        Write-Host "Creating private end point"
        $privateEndpoint3 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "$env:Dataverse_Synapse_Name-pepsqlod" -Location $env:Dataverse_LandingZone_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn3
        $networkInterface3 = Get-AzResource -ResourceId $privateEndpoint3.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        Write-Host "11"
        foreach ($ipconfig in $networkInterface3.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
            Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating private DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.sql.azuresynapse.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }   
        #        $zg = @{
        #            ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "Synapse-SQLOnDemand-PEP" 
        #            PrivateEndpointName = "$env:Dataverse_Synapse_Name-pepsqlod" 
        #            Name = "$env:Dataverse_Synapse_Name-zgsqlod"
                #Name = "SQLOnDemandZoneGroup"
        #            PrivateDnsZoneConfig = $config
        #        }
        #        Write-Host "Creating private DNS zone group"
        #        New-AzPrivateDnsZoneGroup @zg
        
                Write-Host "12"
                Write-Host "Creating private end point connection"
                $privateEndpointConn4 = New-AzPrivateLinkServiceConnection -Name "$env:Dataverse_Synapse_Name-pepcdev" -PrivateLinkServiceId $azsynapse.Id -GroupId "Dev"
                Write-Host "Creating private end point"
                $privateEndpoint4 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "$env:Dataverse_Synapse_Name-pepdev" -Location $env:Dataverse_LandingZone_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn4
        #        Write-Host "Creating private DNS zone"
        #        $dnszone4 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.dev.azuresynapse.net"
        #        Write-Host "Creating private DNS virtual network link"
                #$vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dev.azuresynapse.net" -Name "syn-dev-virtual-link" -VirtualNetworkId $vnetwork.Id
        #        $vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dev.azuresynapse.net" -Name "$env:Dataverse_Synapse_Name-vldev" -VirtualNetworkId $vnetwork.Id
        $networkInterface4 = Get-AzResource -ResourceId $privateEndpoint4.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        Write-Host "13"
        foreach ($ipconfig in $networkInterface4.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
            Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating private DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.dev.azuresynapse.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }   
        #        $cg = @{
        #            Name = "privatelink.dev.azuresynapse.net"
        #            PrivateDnsZoneId = $dnszone4.ResourceId
        #        }
        #        Write-Host "Creating private DNS zone config"
        #        $config = New-AzPrivateDnsZoneConfig @cg
                
                ## Create the DNS zone group. ##
        #        $zg = @{
        #            ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "Synapse-Dev-PEP" 
        #            PrivateEndpointName = "$env:Dataverse_Synapse_Name-pepdev" 
                #Name = "DevZoneGroup"
        #            Name = "$env:Dataverse_Synapse_Name-zgdev"
        #            PrivateDnsZoneConfig = $config
        #        }
        #        Write-Host "Creating private DNS zone group"
        #        New-AzPrivateDnsZoneGroup @zg

        Write-Host "14" 
        Write-Host "Creating private end point connection"
        $privateEndpointConn1 = New-AzPrivateLinkServiceConnection -Name "$env:Dataverse_Synapse_Name-pepcws"  -PrivateLinkServiceId $privatelinkhubid -GroupId "Web"
        
        Write-Host "15"
        Write-Host "Creating private end point"
        $privateEndpoint1 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "$env:Dataverse_Synapse_Name-pepws" -Location $env:Dataverse_LandingZone_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn1
        #        Write-Host "Creating private DNS zone"
        #        $dnszone1 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.azuresynapse.net"
        #        Write-Host "17"
        #        Write-Host "Creating private DNS virtual network link"
                #$vlink1 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.azuresynapse.net" -Name "syn-web-virtual-link" -VirtualNetworkId $vnetwork.Id
        #        $vlink1 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.azuresynapse.net" -Name "$env:Dataverse_Synapse_Name-vlws" -VirtualNetworkId $vnetwork.Id
        #        $networkInterface1 = Get-AzResource -ResourceId $privateEndpoint1.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        #        foreach ($ipconfig in $networkInterface1.properties.ipConfigurations) {
        #            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
        #            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
        #            $recordName = $fqdn.split('.',2)[0]
        #            Write-Host "Record Name is $recordName"
        #            $dnsZone = $fqdn.split('.',2)[1]
        #            Write-Host "DNZ Zone is $dnsZone"
        #            Write-Host "Creating private DNS record set"
        #            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.azuresynapse.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
        #            }
        #        }  

        #        $cg = @{
        #            Name = "privatelink.azuresynapse.net"
        #            PrivateDnsZoneId = $dnszone1.ResourceId
        #        }
        #        Write-Host "Creating private DNS zone config"
        #        $config = New-AzPrivateDnsZoneConfig @cg
                
                ## Create the DNS zone group. ##
        #        $zg = @{
        #            ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "Synapse-Studio-PEP" 
        #            PrivateEndpointName = "$env:Dataverse_Synapse_Name-pepws" 
                #Name = "WebZoneGroup"
        #            Name = "$env:Dataverse_Synapse_Name-zgws"
        #            PrivateDnsZoneConfig = $config
        #        }
        #        Write-Host "Creating private DNS zone group"
        #        New-AzPrivateDnsZoneGroup @zg

        Write-Host "Approve private end point connection from synapse linked services to the adls"
        $storageacc = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:Dataverse_StorageAccount_Name
        $storageacc_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $storageacc.Id | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
        Approve-AzPrivateEndpointConnection -ResourceId $storageacc_epc.Id

    }
    else 
    {
        Write-Host "$env:Dataverse_Synapse_Name exists"
        
    }
}

$synapseWorkspaceVar= "${env:resource_prefix}syn${env:resource_suffix}"
$subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
        #Write-Host "Creating managed private end point to Synapse MDF"
        #$SynapsePrivateLinkResourceId = "/subscriptions/$subid/resourceGroups/$env:ResouceGroup_Name/providers/Microsoft.Storage/Microsoft.Synapse/${env:resource_prefix}syn${env:resource_suffix}"
        #$createPrivateEndpointJsonString = @"
        #{    
        #    "properties": {
        #        "privateLinkResourceId": "$SynapsePrivateLinkResourceId",
        #        "groupId": "SqlOnDemand"
        #    }
        #}
        #"@

        #Write-Host $createPrivateEndpointJsonString

        #$tempFolderPath = ".\temp"

        #if (!(Test-path -path $tempFolderPath)) { 
        #    Write-Host "new file"
        #    New-Item -ItemType directory -path $tempFolderPath
        #}

        #Write-Host "creating the PrivateEndpoint Definition Json file...."
        #$jsonpath = ".\$tempFolderPath\createprivateendpoint.json"

        #Set-Content -Path $jsonpath -value $createPrivateEndpointJsonString

        #Write-Host "Add Synapse Dataverse MI as synapse administrator to Synapse MDF"
        #az synapse role assignment create --workspace-name $env:Synapse_Name --role "Synapse Administrator" --assignee ${env:Dataverse_Synapse_Name} --subscription $env:ResourceGroup_Subscription
        #New-AzSynapseRoleAssignment -WorkspaceName $env:Synapse_Name -RoleDefinitionName "Synapse Administrator" -SignInName ${env:Dataverse_Synapse_Name} #-ObjectId "{AZURE DEVOPS ORGANIZATION OBJECTID"

        #Write-Host "Creating new Managed Private Endpoint from dataverse Synapse to MDF Synapse..."
        #New-AzSynapseManagedPrivateEndpoint `
        #-WorkspaceName $synapseWorkspaceVar `
        #-Name "managedPrivateEndpointAzureFunction" `
        #-DefinitionFile $jsonpath

        #$Synapse_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $SynapsePrivateLinkResourceId | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
        #sleep 60
        #Write-Host "Synapse EPC is $Synapse_epc"
        #Write-Host "Function App EPC ID is "$FunctionApp_epc.Id
        #Write-Host "Approve managed private end point connection from Synapse to MDF Synapse"
        #Approve-AzPrivateEndpointConnection -ResourceId $SynapsePrivateLinkResourceId

        #Add-AzureRmAccount -ServicePrincipal -Credential $Credential -TenantId ${env:SP_TENANT_ID}
        #Write-Host "222"
        #Get-AzureRmADApplication -ObjectId $ObjectIdOfApplicationToChange
        #Write-Host "333"
        #$ctx = Get-AzureRmContext
        #Write-Host "444"
        #$cache = $ctx.TokenCache
        #Write-Host "555"
        #$cacheItems = $cache.ReadItems()
        #Write-Host "666"
        #$token = ($cacheItems | where { $_.Resource -eq "https://graph.windows.net/" })
        #Write-Information "Login to AzureAD with same SP: ${env:SP_CLIENT_ID}"
        #Connect-AzureAD -AadAccessToken $token.AccessToken -AccountId $ctx.Account.Id -TenantId $ctx.Tenant.Id
        #$dataverse_sp_object_id = Get-AzureADServicePrincipal -SearchString $env:Dataverse_SP_Name | select ObjectId
        #Write-Host "Dataverse SP Object ID is $dataverse_sp_object_id"
        #$AAD_Group_Admin_id = Get-AzureADGroup -SearchString $env:AAD_Group_Admin_name | select ObjectId
        #Write-Host "AAD Group admin ID is $AAD_Group_Admin_id"
if($env:Dataverse_LandingZone_GrantRBAC -eq "True")
{
    Write-Host "Start RBAC of Landing Zone"
    az login --service-principal -u ${env:SP_CLIENT_ID} -p ${env:SP_CLIENT_SECRET} --tenant ${env:SP_TENANT_ID}
    az config set extension.use_dynamic_install=yes_without_prompt
    $subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
    $basescope = "/subscriptions/$subid/resourceGroups/$env:ResouceGroup_Name/providers"
    $basescope1 = "/subscriptions/$subid/resourceGroups/$env:ResouceGroup_Name"

    Write-Host "Assigning SP Export to data lake  as reader of Resource Group.."
    az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Reader" --scope $basescope1
    #az role assignment create --assignee-object-id $dataverse_sp_object_id --assignee-principal-type "ServicePrincipal" --role "Reader" --scope $basescope1
    Write-Host "Assigning SP Export to data lake  as Owner of LZ storage account.."
    az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Owner" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"
    #az role assignment create --assignee-object-id $dataverse_sp_object_id --assignee-principal-type "ServicePrincipal" --role "Owner" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"

    Write-Host "Assigning SP Export to data lake  as Storage Contributor of LZ storage account.."
    az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"
    #az role assignment create --assignee-object-id $dataverse_sp_object_id --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"

    Write-Host "Assigning SP Export to data lake  as Owner of Synapse.."
    az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Owner" --scope "$basescope/Microsoft.Synapse/workspaces/$env:Dataverse_Synapse_Name"
    #az role assignment create --assignee-object-id $dataverse_sp_object_id --assignee-principal-type "ServicePrincipal" --role "Owner" --scope "$basescope/Microsoft.Synapse/workspaces/$env:Dataverse_Synapse_Name"

    Write-Host "Assigning SP Export to data lake as Synapse Administrator of Synapse.."
    az synapse role assignment create --workspace-name $env:Dataverse_Synapse_Name --role "Synapse Administrator" --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --subscription $env:ResourceGroup_Subscription
    #az synapse role assignment create --workspace-name $env:Dataverse_Synapse_Name --role "Synapse Administrator" --assignee-object-id $dataverse_sp_object_id --assignee-principal-type "ServicePrincipal" --subscription $env:ResourceGroup_Subscription
    
    Write-Host "Assigning MDF Synapse  as Synapse Administrator of Synapse LZ.."
    az synapse role assignment create --workspace-name "${env:resource_prefix}syn${env:resource_suffix}" --role "Synapse Administrator" --scope "$basescope/Microsoft.Synapse/workspaces/$env:Dataverse_Synapse_Name"


    Write-Host "Assigning AAD group admin  as reader of Resource Group.."
    #az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Reader" --scope $basescope1
    az role assignment create --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --role "Reader" --scope $basescope1
    Write-Host "Assigning AAD group admin  as Owner of LZ storage account.."
    #az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Owner" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"
    az role assignment create --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --role "Owner" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"

    Write-Host "Assigning AAD group admin  as Storage Contributor of LZ storage account.."
    #az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"
    az role assignment create --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --role "Storage Blob Data Contributor" --scope "$basescope/Microsoft.Storage/storageAccounts/$env:Dataverse_StorageAccount_Name"

    Write-Host "Assigning AAD group admin  as Owner of Synapse.."
    #az role assignment create --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --role "Owner" --scope "$basescope/Microsoft.Synapse/workspaces/$env:Dataverse_Synapse_Name"
    az role assignment create --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --role "Owner" --scope "$basescope/Microsoft.Synapse/workspaces/$env:Dataverse_Synapse_Name"

    Write-Host "Assigning AAD group admin as Synapse Administrator of Synapse.."
    #az synapse role assignment create --workspace-name $env:Dataverse_Synapse_Name --role "Synapse Administrator" --assignee-object-id ${env:Dataverse_SP_OBJECT_ID} --assignee-principal-type "ServicePrincipal" --subscription $env:ResourceGroup_Subscription
    az synapse role assignment create --workspace-name $env:Dataverse_Synapse_Name --role "Synapse Administrator" --assignee-object-id ${env:AAD_Group_Admin_ID} --assignee-principal-type "Group" --subscription $env:ResourceGroup_Subscription



}
