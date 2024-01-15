if($env:FunctionApp_PrivateEndPoint_Enable -eq "True")
{
#$functionapp_ep = Get-AzPrivateEndpoint -Name "functionapp-PEP" -ResourceGroupName $env:ResouceGroup_Name
#if ($functionapp_ep -eq $False) 
#{   
    $vnet_name = $env:VNET_Name 
    $vnetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name $vnet_name 
    $vsubnet = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $env:default_Subnet_Name}

    $FunctionApp = Get-AzFunctionApp -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}functionapp${env:resource_suffix}"
    Write-Host "4 and function id is " $FunctionApp.Id
    #$subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
    Write-Host "Creating private end point connection"
    #$privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "functionapp-PEPC" -PrivateLinkServiceId $FunctionApp.Id -GroupId "sites"
    $privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "${env:resource_prefix}functionapp${env:resource_suffix}-pepc" -PrivateLinkServiceId $FunctionApp.Id -GroupId "sites"
    Write-Host "5"
    Write-Host "Creating private end point"
    #$privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "functionapp-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2
    $privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}functionapp${env:resource_suffix}-pep" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2 -Force
    Write-Host "6"
    Write-Host "Creating private DNS zone"
    $dnszone2 = New-AzPrivateDnsZone -ResourceGroupName $env:ResouceGroup_Name -Name "privatelink.azurewebsites.net"
    Write-Host "7"
    Write-Host "Creating private DNS virtual network link"
    #$vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.azurewebsites.net" -Name "functionapp-virtual-link" -VirtualNetworkId $vnetwork.Id
    $vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:ResouceGroup_Name -ZoneName "privatelink.azurewebsites.net" -Name "${env:resource_prefix}functionapp${env:resource_suffix}-vl" -VirtualNetworkId $vnetwork.Id
    Write-Host "8"
    $networkInterface2 = Get-AzResource -ResourceId $privateEndpoint2.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
    #$networkInterface2 = Get-AzResource -ResourceId $privateEndpoint2.NetworkInterfaces[0] -ApiVersion "2019-04-01"
    Write-Host "9"
    #foreach ($ipconfig in $networkInterface2.properties.ipConfigurations) {
    # Write-Host "Ip Config is" $ipconfig
    # foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
    # Write-Host "fqdn is " $fqdn  
    # Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
    # $recordName = $fqdn.split('.',2)[0] 
                  #$fqdn.split('.')[0,1] -join '.'
    # Write-Host "Record Name is $recordName"
    # $dnsZone = $fqdn.split('.',2)[1]
    # Write-Host "DNZ Zone is $dnsZone"
    # New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.azurewebsites.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
    # }
    #}
    $ipconfig = $networkInterface2.properties.ipConfigurations[0] 
    Write-Host "IP config is " $ipconfig
    $fqdn =  $ipconfig.properties.privateLinkConnectionProperties.fqdns[0]
    Write-Host "fqdn is " $fqdn
    $recordName = $fqdn.split('.',2)[0]
    Write-Host "Record Name is $recordName"
    $dnsZone = $fqdn.split('.',2)[1]
    Write-Host "DNZ Zone is $dnsZone" 
    Write-Host "Creating private DNS record set"
    New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.azurewebsites.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress) 

    #$ipconfig = $networkInterface2.properties.ipConfigurations[1] 
    #Write-Host "IP config is " $ipconfig
    $fqdn =  $ipconfig.properties.privateLinkConnectionProperties.fqdns[1]
    Write-Host "fqdn is " $fqdn
    $recordName = $fqdn.split('.')[0,1] -join '.'
    Write-Host "Record Name is $recordName"
    #$dnsZone = $fqdn.split('.',2)[1]
    #Write-Host "DNZ Zone is $dnsZone" 
    Write-Host "Creating private DNS record set"
    New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.azurewebsites.net" -ResourceGroupName $env:ResouceGroup_Name -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress) 

    $cg = @{
        Name = 'privatelink.azurewebsites.net'
        PrivateDnsZoneId = $dnszone2.ResourceId
    }
    Write-Host "Creating private DNS zone config"
    $config = New-AzPrivateDnsZoneConfig @cg
 
    ## Create the DNS zone group. ##
    $zg = @{
        ResourceGroupName = $env:ResouceGroup_Name
        #PrivateEndpointName = "functionapp-PEP" 
        PrivateEndpointName = "${env:resource_prefix}functionapp${env:resource_suffix}-pep"
        #Name = 'functionappZoneGroup'
        Name = "${env:resource_prefix}functionapp${env:resource_suffix}-zg"
        PrivateDnsZoneConfig = $config
    }
    Write-Host "Creating private DNS zone group"
    New-AzPrivateDnsZoneGroup @zg -Force
#}
#else 
#{
#    Write-Host "functionapp-PEP already exists"
    
#}
}
