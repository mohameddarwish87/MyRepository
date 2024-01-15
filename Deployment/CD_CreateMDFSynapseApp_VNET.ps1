if($env:Synapse_Enable -eq "True" -and $env:VNET_Enable -eq "True")
{
    #$Synapse = Test-AzSynapseWorkspace -Name $env:Synapse_Name -ResourceGroupName $env:ResouceGroup_Name
    $Synapse = Test-AzSynapseWorkspace -Name "${env:resource_prefix}syn${env:resource_suffix}" -ResourceGroupName $env:ResouceGroup_Name    
    $synapseWorkspaceVar= "${env:resource_prefix}syn${env:resource_suffix}"
    if ($Synapse -eq $False) 
    {   
        Write-Host "Creating Azure Synapse inside VNET..."
        $secret =  Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_Synapse_DBPassword -AsPlainText
        $tenant =  Get-AzKeyVaultSecret -VaultName $env:KeyVault_Name -Name $env:KeyVault_SP_TenantId -AsPlainText
        New-AzResourceGroupDeployment -ResourceGroupName $env:ResouceGroup_Name `
        -TemplateFile .\Deployment\arm\06-Synapse-VNET4.json `
        -workspaces_intergen_data_mdp_synapse_dev_name "${env:resource_prefix}syn${env:resource_suffix}" `
        -storage_account_name $env:StorageAccount_Name `
        -Synapse_SqlAdministratorLogin $env:Synapse_SqlAdministratorLogin `
        -Synapse_SqlAdministratorPassword $secret `
        -spark_pool_name $env:Synapse_PoolName `
        -spark_pool_shutdown_time $env:Synapse_ShutDown_Time `
        -tenantId $tenant `
        -Synapse_managed_resource_group $env:Synapse_ManagedResourceGroup `
        -PrivateLinkHub $env:Synapse_PrivateLinkHub `
        -KeyVault_Name $env:KeyVault_Name 

        Write-Host "1"
        $vnetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $env:VNET_Name
        Write-Host "2"
        $vsubnet = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $env:default_Subnet_Name}
        Write-Host "3"
        #$azsynapse = Get-AzSynapseWorkspace -Name $env:Synapse_Name
        $azsynapse = Get-AzSynapseWorkspace -Name "${env:resource_prefix}syn${env:resource_suffix}"
        Write-Host "4"
        $subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
        $privatelinkhub = $env:Synapse_PrivateLinkHub
        #$privatelinkhub = "${env:resource_prefix}syn${env:resource_suffix}-lh"
        $privatelinkhubid="/subscriptions/$subid/resourceGroups/$env:ResouceGroup_Name/providers/Microsoft.Synapse/privateLinkHubs/$privatelinkhub"
        Write-Host "Creating private end point connection"
        #$privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "Synapse-SQL-PEPC" -PrivateLinkServiceId $azsynapse.Id -GroupId "SQL"
        $privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "${env:resource_prefix}syn${env:resource_suffix}-pepcsql" -PrivateLinkServiceId $azsynapse.Id -GroupId "SQL"
        Write-Host "5"
        Write-Host "Creating private end point"
        #$privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "Synapse-SQL-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2
        $privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}syn${env:resource_suffix}-pepsql" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2
        Write-Host "6"
        Write-Host "Creating private DNS zone"
        $dnszone2 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.sql.azuresynapse.net"
        $dnszone2 = Get-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.sql.azuresynapse.net"
        Write-Host "7"
        Write-Host "Creating private DNS virtual network link"
        #$vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.sql.azuresynapse.net" -Name "syn-sql-virtual-link" -VirtualNetworkId $vnetwork.Id
        $vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.sql.azuresynapse.net" -Name "${env:resource_prefix}syn${env:resource_suffix}-vlsql" -VirtualNetworkId $vnetwork.Id
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
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.sql.azuresynapse.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }   

        $cg = @{
            Name = "privatelink.sql.azuresynapse.net"
            PrivateDnsZoneId = $dnszone2.ResourceId
        }
        Write-Host "Creating private DNS zone config"
        $config = New-AzPrivateDnsZoneConfig @cg
        
        ## Create the DNS zone group. ##
        $zg = @{
            ResourceGroupName = $env:ResouceGroup_Name
            #PrivateEndpointName = "Synapse-SQL-PEP" 
            PrivateEndpointName = "${env:resource_prefix}syn${env:resource_suffix}-pepsql"
            #Name = "SQLZoneGroup"
            Name = "${env:resource_prefix}syn${env:resource_suffix}-zgsql"
            PrivateDnsZoneConfig = $config
        }
        Write-Host "Creating private DNS zone group"
        New-AzPrivateDnsZoneGroup @zg 
        
        Write-Host "10"
        Write-Host "Creating private end point connection"
        #$privateEndpointConn3 = New-AzPrivateLinkServiceConnection -Name "Synapse-SQLOnDemand-PEPC" -PrivateLinkServiceId $azsynapse.Id -GroupId "SqlOnDemand"
        $privateEndpointConn3 = New-AzPrivateLinkServiceConnection -Name "${env:resource_prefix}syn${env:resource_suffix}-pepcsqlod" -PrivateLinkServiceId $azsynapse.Id -GroupId "SqlOnDemand"
        Write-Host "Creating private end point"
        #$privateEndpoint3 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "Synapse-SQLOnDemand-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn3
        $privateEndpoint3 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}syn${env:resource_suffix}-pepsqlod" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn3
        #beth below lines already exist
        #$dnszone3 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.sql.azuresynapse.net"
        #$vlink3 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelinkdarwish1.sql.azuresynapse.net" -Name "darwish1-syn-sqlOnDemand-virtual-link" -VirtualNetworkId $vnetwork.Id
        #$networkInterface3 = Get-AzResource -ResourceId $privateEndpoint3.NetworkInterfaces[0] -ApiVersion "2019-04-01"
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
        #Below commented as it is not needed
        #'''$cg = @{
        #    Name = privatelink.sql.azuresynapse.net
        #    PrivateDnsZoneId = $dnszone2.ResourceId
        #}
        #$config = New-AzPrivateDnsZoneConfig @cg'''
                
        ## Create the DNS zone group. ##
        $zg = @{
            ResourceGroupName = $env:ResouceGroup_Name
            #PrivateEndpointName = "Synapse-SQLOnDemand-PEP" 
            PrivateEndpointName = "${env:resource_prefix}syn${env:resource_suffix}-pepsqlod" 
            Name = "${env:resource_prefix}syn${env:resource_suffix}-zgsqlod"
            #Name = "SQLOnDemandZoneGroup"
            PrivateDnsZoneConfig = $config
        }
        Write-Host "Creating private DNS zone group"
        New-AzPrivateDnsZoneGroup @zg

        Write-Host "12"
        Write-Host "Creating private end point connection"
        #$privateEndpointConn4 = New-AzPrivateLinkServiceConnection -Name "Synapse-Dev-PEPC" -PrivateLinkServiceId $azsynapse.Id -GroupId "Dev"
        $privateEndpointConn4 = New-AzPrivateLinkServiceConnection -Name "${env:resource_prefix}syn${env:resource_suffix}-pepcdev" -PrivateLinkServiceId $azsynapse.Id -GroupId "Dev"
        Write-Host "Creating private end point"
        #$privateEndpoint4 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "Synapse-Dev-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn4
        $privateEndpoint4 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}syn${env:resource_suffix}-pepdev" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn4
        Write-Host "Creating private DNS zone"
        $dnszone4 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.dev.azuresynapse.net"
        $dnszone4 = Get-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.dev.azuresynapse.net"
        Write-Host "Creating private DNS virtual network link"
        #$vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dev.azuresynapse.net" -Name "syn-dev-virtual-link" -VirtualNetworkId $vnetwork.Id
        $vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dev.azuresynapse.net" -Name "${env:resource_prefix}syn${env:resource_suffix}-vldev" -VirtualNetworkId $vnetwork.Id
        $networkInterface4 = Get-AzResource -ResourceId $privateEndpoint4.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        #$networkInterface4 = Get-AzResource -ResourceId $privateEndpoint4.NetworkInterfaces[0] -ApiVersion "2019-04-01"
        
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

        $cg = @{
            Name = "privatelink.dev.azuresynapse.net"
            PrivateDnsZoneId = $dnszone4.ResourceId
        }
        Write-Host "Creating private DNS zone config"
        $config = New-AzPrivateDnsZoneConfig @cg
        
        ## Create the DNS zone group. ##
        $zg = @{
            ResourceGroupName = $env:ResouceGroup_Name
            #PrivateEndpointName = "Synapse-Dev-PEP" 
            PrivateEndpointName = "${env:resource_prefix}syn${env:resource_suffix}-pepdev" 
            #Name = "DevZoneGroup"
            Name = "${env:resource_prefix}syn${env:resource_suffix}-zgdev"
            PrivateDnsZoneConfig = $config
        }
        Write-Host "Creating private DNS zone group"
        New-AzPrivateDnsZoneGroup @zg
        Write-Host "14" 
        Write-Host "Creating private end point connection"
        #$privateEndpointConn1 = New-AzPrivateLinkServiceConnection -Name "Synapse-Studio-PEPC" -PrivateLinkServiceId $privatelinkhubid -GroupId "Web"
        $privateEndpointConn1 = New-AzPrivateLinkServiceConnection -Name "${env:resource_prefix}syn${env:resource_suffix}-pepcws"  -PrivateLinkServiceId $privatelinkhubid -GroupId "Web"
        
        Write-Host "15"
        Write-Host "Creating private end point"
        #$privateEndpoint1 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "Synapse-Studio-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn1
        $privateEndpoint1 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}syn${env:resource_suffix}-pepws" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn1
        
        Write-Host "16"
        Write-Host "Creating private DNS zone"
        $dnszone1 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.azuresynapse.net"
        $dnszone1 = Get-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.azuresynapse.net"
        Write-Host "17"
        Write-Host "Creating private DNS virtual network link"
        #$vlink1 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.azuresynapse.net" -Name "syn-web-virtual-link" -VirtualNetworkId $vnetwork.Id
        $vlink1 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.azuresynapse.net" -Name "${env:resource_prefix}syn${env:resource_suffix}-vlws" -VirtualNetworkId $vnetwork.Id
        Write-Host "18"
        $networkInterface1 = Get-AzResource -ResourceId $privateEndpoint1.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        #$networkInterface1 = Get-AzResource -ResourceId $privateEndpoint1.NetworkInterfaces[0] -ApiVersion "2019-04-01"
        Write-Host "19"

        foreach ($ipconfig in $networkInterface1.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
            Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating private DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.azuresynapse.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
        }  

        $cg = @{
            Name = "privatelink.azuresynapse.net"
            PrivateDnsZoneId = $dnszone1.ResourceId
        }
        Write-Host "Creating private DNS zone config"
        $config = New-AzPrivateDnsZoneConfig @cg
        
        ## Create the DNS zone group. ##
        $zg = @{
            ResourceGroupName = $env:ResouceGroup_Name
            #PrivateEndpointName = "Synapse-Studio-PEP" 
            PrivateEndpointName = "${env:resource_prefix}syn${env:resource_suffix}-pepws" 
            #Name = "WebZoneGroup"
            Name = "${env:resource_prefix}syn${env:resource_suffix}-zgws"
            PrivateDnsZoneConfig = $config
        }
        Write-Host "Creating private DNS zone group"
        New-AzPrivateDnsZoneGroup @zg
        Write-Host "20" 
        #Create linked service to storage account -- comment below as it is not needed as it is created by default
        #Set-AzSynapseLinkedService -WorkspaceName $env:Synapse_Name -Name "$env:Synapse_Name-WorkspaceDefaultStorage2" -DefinitionFile ".\Deployment\arm\storage_account_DF2.json"

        Write-Host "Approve private end point connection from synapse linked services to the adls"
        $storageacc = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:StorageAccount_Name
        $storageacc_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $storageacc.Id | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
        Approve-AzPrivateEndpointConnection -ResourceId $storageacc_epc.Id

#####################################################
Write-Host "Creating Custom LinkedService in Synapse"
$createCustomLinkedServiceJsonString = @"
{
    "name": "Azure_Synapse_Serverless_WorkspaceDefaultSqlServer",
    "type": "Microsoft.Synapse/workspaces/linkedservices",
    "properties": {
        "parameters": {
            "DBName": {
                "type": "string"
            },
            "ServerName": {
                "type": "string"
            }
        },
        "annotations": [],
        "type": "AzureSqlDW",
        "typeProperties": {
            "connectionString": "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=@{linkedService().ServerName};Initial Catalog=@{linkedService().DBName}"
        },
        "connectVia": {
            "referenceName": "AutoResolveIntegrationRuntime",
            "type": "IntegrationRuntimeReference"
        }
    }
}
"@


Write-Host $createCustomLinkedServiceJsonString

$tempFolderPath = ".\temp"

if (!(Test-path -path $tempFolderPath)) { 
    Write-Host "new file"
    New-Item -ItemType directory -path $tempFolderPath
}

Write-Host "creating the Linked Service Definition Json file...."
$jsonpath = ".\$tempFolderPath\createlinkedservice.json"

Set-Content -Path $jsonpath -value $createCustomLinkedServiceJsonString

Write-Host "Creating new custom linked service in synapse..."
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceVar -Name "Azure_Synapse_Serverless_WorkspaceDefaultSqlServer"  -DefinitionFile $jsonpath

#####################################################        

    }
    else 
    {
        Write-Host "$env:Synapse_Name exists"
       
    }
}
