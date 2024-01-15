
if($env:StorageAccount_Enable -eq "True" -and $env:VNET_Enable -eq "True")
{
    $StorageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:StorageAccount_Name -ErrorAction SilentlyContinue
    $vnetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $env:VNET_Name  
    if ($null -eq $StorageAccount) 
    {
        Write-Host "Creating Storage Account inside VNET..."
        New-AzResourceGroupDeployment `
        -ResourceGroupName $env:ResouceGroup_Name `
        -TemplateFile .\Deployment\arm\01-Storage5-VNET3.json `
        -storageAccountName $env:StorageAccount_Name `
        -storageSKU $env:StorageAccount_SKU `
        -IsHierarchyEnabled $env:StorageAccount_HierarchyEnable `
        -VNETId $vnetwork.Id `
        -StorageAccount_SubnetName $env:default_Subnet_Name
        
        Write-Host "2"
        $vsubnet = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $env:default_Subnet_Name}
        Write-Host "3"
        $storageacc = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:StorageAccount_Name
        Write-Host "4"
        $subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
        Write-Host "Creating private end point connection"
        #$privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "adls-blob-PEPC" -PrivateLinkServiceId $storageacc.Id -GroupId "blob"
        $privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "${env:StorageAccount_Name}-pepcblob" -PrivateLinkServiceId $storageacc.Id -GroupId "blob"
        Write-Host "5"
        Write-Host "Creating private end point"
        #$privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "adls-blob-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2
        $privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:StorageAccount_Name}-pepblob" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2
        Write-Host "6"
        Write-Host "Creating private DNS zone"
        $dnszone2 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.blob.core.windows.net"
        $dnszone2 = Get-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.blob.core.windows.net"
        Write-Host "7"
        Write-Host "Creating private DNS virtual network link"
        #$vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.blob.core.windows.net" -Name "adls-blob-virtual-link" -VirtualNetworkId $vnetwork.Id
        $vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.blob.core.windows.net" -Name "${env:StorageAccount_Name}-vlblob" -VirtualNetworkId $vnetwork.Id
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

        $cg = @{
            Name = 'privatelink.blob.core.windows.net'
            PrivateDnsZoneId = $dnszone2.ResourceId
        }
        Write-Host "Creating private DNS zone config"
        $config = New-AzPrivateDnsZoneConfig @cg
        
        ## Create the DNS zone group. ##
        $zg = @{
            ResourceGroupName = $env:ResouceGroup_Name
            #PrivateEndpointName = "adls-blob-PEP" 
            PrivateEndpointName = "${env:StorageAccount_Name}-pepblob"
            #Name = 'blobZoneGroup'
            Name = "${env:StorageAccount_Name}-zgblob"
            PrivateDnsZoneConfig = $config
        }
        Write-Host "Creating private DNS zone group"
        New-AzPrivateDnsZoneGroup @zg
        
        Write-Host "Creating private end point connection"
        $privateEndpointConn3 = New-AzPrivateLinkServiceConnection -Name "${env:StorageAccount_Name}-pepcdfs" -PrivateLinkServiceId $storageacc.Id -GroupId "dfs"
        #$privateEndpointConn3 = New-AzPrivateLinkServiceConnection -Name "adls-dfs-PEPC" -PrivateLinkServiceId $storageacc.Id -GroupId "dfs"
        Write-Host "10"
        Write-Host "Creating private end point"
        #$privateEndpoint3 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "adls-dfs-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn3
        $privateEndpoint3 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:StorageAccount_Name}-pepdfs" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn3
        Write-Host "11"
        Write-Host "Creating private DNS zone"
        $dnszone3 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.dfs.core.windows.net"
        $dnszone3 = Get-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.dfs.core.windows.net"
        Write-Host "12"
        Write-Host "Creating private DNS virtual network link"
        #$vlink3 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dfs.core.windows.net" -Name "adls-dfs-virtual-link" -VirtualNetworkId $vnetwork.Id
        $vlink3 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.dfs.core.windows.net" -Name "${env:StorageAccount_Name}-vldfs" -VirtualNetworkId $vnetwork.Id
        Write-Host "13"
        $networkInterface3 = Get-AzResource -ResourceId $privateEndpoint3.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        #$networkInterface3 = Get-AzResource -ResourceId $privateEndpoint3.NetworkInterfaces[0] -ApiVersion "2019-04-01"
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
        $cg = @{
            Name = 'privatelink.dfs.core.windows.net'
            PrivateDnsZoneId = $dnszone3.ResourceId
        }
        Write-Host "Creating private DNS zone config"
        $config = New-AzPrivateDnsZoneConfig @cg
        
        ## Create the DNS zone group. ##
        $zg = @{
            ResourceGroupName = $env:ResouceGroup_Name
            #PrivateEndpointName = "adls-dfs-PEP" 
            PrivateEndpointName = "${env:StorageAccount_Name}-pepdfs" 
            #Name = 'dfsZoneGroup'
            Name = "${env:StorageAccount_Name}-zgdfs"
            PrivateDnsZoneConfig = $config
        }    
        Write-Host "Creating private DNS zone group"
        New-AzPrivateDnsZoneGroup @zg


        Write-Host "Creating private end point connection"
        #$privateEndpointConn4 = New-AzPrivateLinkServiceConnection -Name "adls-file-PEPC" -PrivateLinkServiceId $storageacc.Id -GroupId "file"
        $privateEndpointConn4 = New-AzPrivateLinkServiceConnection -Name "${env:StorageAccount_Name}-pepcfile" -PrivateLinkServiceId $storageacc.Id -GroupId "file"
        Write-Host "15"
        Write-Host "Creating private end point"
        #$privateEndpoint4 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "adls-file-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn4
        $privateEndpoint4 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:StorageAccount_Name}-pepfile" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn4
        Write-Host "16"
        Write-Host "Creating private DNS zone"
        $dnszone4 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.file.core.windows.net"
        $dnszone4 = Get-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.file.core.windows.net"
        Write-Host "17"
        Write-Host "Creating private DNS virtual network link"
        #$vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.file.core.windows.net" -Name "adls-file-virtual-link" -VirtualNetworkId $vnetwork.Id
        $vlink4 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.file.core.windows.net" -Name "${env:StorageAccount_Name}-vlfile" -VirtualNetworkId $vnetwork.Id
        Write-Host "18"
        $networkInterface4 = Get-AzResource -ResourceId $privateEndpoint4.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
        #$networkInterface4 = Get-AzResource -ResourceId $privateEndpoint4.NetworkInterfaces[0] -ApiVersion "2019-04-01"
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
        $cg = @{
            Name = 'privatelink.file.core.windows.net'
            PrivateDnsZoneId = $dnszone4.ResourceId
        }
        Write-Host "Creating private DNS zone config"
        $config = New-AzPrivateDnsZoneConfig @cg
        
        ## Create the DNS zone group. ##
        $zg = @{
            ResourceGroupName = $env:ResouceGroup_Name
            #PrivateEndpointName = "adls-file-PEP" 
            PrivateEndpointName = "${env:StorageAccount_Name}-pepfile"
            #Name = 'dfsZoneGroup'
            Name = "${env:StorageAccount_Name}-zgfile"
            PrivateDnsZoneConfig = $config
        }    
        Write-Host "Creating private DNS zone group"
        New-AzPrivateDnsZoneGroup @zg

    }
    else
    {
        Write-Host "$env:StorageAccount_Name exists"

    }
    
}
Write-Host "Creating containers if not exists..."
#$AccessKey = Get-AzStorageAccountKey -ResourceGroupName $env:ResouceGroup_Name -storageAccountName $env:StorageAccount_Name
$storageAcc = Get-AzStorageAccount -StorageAccountName $env:StorageAccount_Name -ResourceGroupName $env:ResouceGroup_Name #-StorageAccountKey $AccessKey[0].Value
$ctx=$storageAcc.Context 
$landingexist = Get-AzStorageContainer -Context $ctx | Where-Object { $_.Name -eq $env:StorageAccount_LandingContainer }
if ($null -eq $landingexist)
{
    New-AzStorageContainer -Name $env:StorageAccount_LandingContainer -Context $ctx -Permission Container
}
$stagingexist = Get-AzStorageContainer -Context $ctx | Where-Object { $_.Name -eq $env:StorageAccount_StagingContainer }
if ($null -eq $stagingexist)
{   
    New-AzStorageContainer -Name $env:StorageAccount_StagingContainer -Context $ctx -Permission Container
}
$rawexist = Get-AzStorageContainer -Context $ctx | Where-Object { $_.Name -eq $env:StorageAccount_RawContainer }
if ($null -eq $rawexist)
{
    New-AzStorageContainer -Name $env:StorageAccount_RawContainer -Context $ctx -Permission Container
}
$curatedexist = Get-AzStorageContainer -Context $ctx | Where-Object { $_.Name -eq $env:StorageAccount_CuratedContainer }
if ($null -eq $curatedexist)
{
    New-AzStorageContainer -Name $env:StorageAccount_CuratedContainer -Context $ctx -Permission Container
}
$systemexist = Get-AzStorageContainer -Context $ctx | Where-Object { $_.Name -eq "system" }
if ($null -eq $systemexist)
{
    New-AzStorageContainer -Name "system" -Context $ctx  -Permission Container
}

Write-Host "Uploading necessary files to the system zone..."
    $filesystemName = "system"  
    $localSrcFile =  "Resources/ADLS/Functions/ConvertToDelta.py"
    $dirname = "Functions/"
    $destPath = $dirname + (Get-Item $localSrcFile).Name
    New-AzDataLakeGen2Item -Context $ctx -FileSystem $filesystemName -Path $destPath -Source $localSrcFile -Force



