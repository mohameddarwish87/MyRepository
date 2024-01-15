
if($env:KeyVault_Enable -eq "True" -and $env:VNET_Enable -eq "True")
{
    $SP_Object_ID = ${env:SP_Object_ID}
    #$KeyVault = Get-AzKeyVault -VaultName $env:KeyVault_Name -ResourceGroupName $env:KeyVault_ResourceGroup -ErrorAction SilentlyContinue
    $KeyVault = Get-AzKeyVault -VaultName  $env:KeyVault_Name-ResourceGroupName $env:KeyVault_ResourceGroup -ErrorAction SilentlyContinue
    if($null -eq $KeyVault)
    {
        #$KeyVault1 = Get-AzKeyVault -VaultName $env:KeyVault_Name -Location $env:ResourceGroup_Location -InRemovedState -ErrorAction SilentlyContinue
        $KeyVault1 = Get-AzKeyVault -VaultName $env:KeyVault_Name -Location $env:ResourceGroup_Location -InRemovedState -ErrorAction SilentlyContinue
        if ($null -eq $KeyVault1) 
        {
           Write-Host "1"
           $vnetwork = Get-AzVirtualNetwork -ResourceGroupName $env:KeyVault_ResourceGroup -Name $env:VNET_Name  
           Write-Host "Creating Azure Key Vault inside VNET..."
           New-AzResourceGroupDeployment `
           -ResourceGroupName $env:KeyVault_ResourceGroup `
           -TemplateFile .\Deployment\arm\05-KeyVault-VNET.json `
           -keyVaultName  $env:KeyVault_Name `
           -objectId $SP_Object_ID `
           -VNETId $vnetwork.Id `
           -DefaultSubnetName $env:default_Subnet_Name
           
        }
        else 
        {
            #Write-Host "$env:KeyVault_Name exists but is in soft-deleted state"
            Write-Host "${env:resource_prefix}kv${env:resource_suffix} exists but is in soft-deleted state"
        }
    }
    else
    {
        #Write-Host "$env:KeyVault_Name already exists"
        Write-Host "$env:resource_prefixkv$env:resource_suffix already exists"
    }
    #Set-AzKeyVaultAccessPolicy -VaultName $env:KeyVault_Name -ObjectId $SP_Object_ID -PermissionsToSecrets Get,List,Set
    Set-AzKeyVaultAccessPolicy -VaultName $env:KeyVault_Name -ObjectId $SP_Object_ID -PermissionsToSecrets Get,List,Set
    Write-Host "aaa"
    $SP_Client_ID = ConvertTo-SecureString ${env:SP_Client_ID} -AsPlainText -Force
    Write-Host "bbb $SP_Client_ID"
    $SP_Object_ID = ConvertTo-SecureString ${env:SP_Object_ID} -AsPlainText -Force
    Write-Host "ccc $SP_Object_ID"
    $SP_Client_Secret = ConvertTo-SecureString ${env:SP_Client_Secret} -AsPlainText -Force
    Write-Host "ddd $SP_Client_Secret"
    $SP_Tenant_ID = ConvertTo-SecureString ${env:SP_Tenant_ID} -AsPlainText -Force
    Write-Host "eee $SP_Tenant_ID"
    $Synapse_DBPassword = ConvertTo-SecureString ${env:Synapse_SqlAdministratorPassword_secret} -AsPlainText -Force
    Write-Host "fff $Synapse_DBPassword"
    $VM_Password = ConvertTo-SecureString ${env:VM_Password} -AsPlainText -Force
    Write-Host "hhh $VM_Password"
    $ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    $virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $env:KeyVault_ResourceGroup -Name $env:VNET_Name
    Write-Host "1"
    $sub=Get-AzVirtualNetworkSubnetConfig -Name $env:default_Subnet_Name -VirtualNetwork $virtualNetwork
    #Write-Host "Add Devops IP to KV Firewall 2"
    #Add-AzKeyVaultNetworkRule -VaultName $env:KeyVault_Name  -IpAddressRange $ip -VirtualNetworkResourceId $sub.Id -PassThru
    #Write-Host "Add Devops IP to KV Firewall 3"
    #Start-Sleep -Seconds 240
    
    if($null -eq $KeyVault)
    {
        #$KeyVault1 = Get-AzKeyVault -VaultName $env:KeyVault_Name -Location $env:ResourceGroup_Location -InRemovedState -ErrorAction SilentlyContinue
        if ($null -eq $KeyVault1) 
        {
            Write-Host "2"
            $vsubnet = $vnetwork | Select -ExpandProperty subnets | Where-Object {$_.Name -eq $env:default_Subnet_Name}
            Write-Host "3"
            #$kv = Get-AzKeyVault -ResourceGroupName $env:KeyVault_ResourceGroup -VaultName $env:KeyVault_Name
            $kv = Get-AzKeyVault -ResourceGroupName $env:KeyVault_ResourceGroup -VaultName $env:KeyVault_Name
            Write-Host "4"
            $subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
            Write-Host "Creating private end point connection"
            #$privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "kv-PEPC" -PrivateLinkServiceId $kv.ResourceId -GroupId "vault"
            $privateEndpointConn2 = New-AzPrivateLinkServiceConnection -Name "${env:resource_prefix}kv${env:resource_suffix}-pepc" -PrivateLinkServiceId $kv.ResourceId -GroupId "vault"
            Write-Host "Creating private end point"
            #$privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:KeyVault_ResourceGroup -Name "kv-PEP" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2 -Force
            $privateEndpoint2 = New-AzPrivateEndpoint -ResourceGroupName $env:KeyVault_ResourceGroup -Name "${env:resource_prefix}kv${env:resource_suffix}-pep" -Location $env:ResourceGroup_Location -Subnet $vsubnet -PrivateLinkServiceConnection $privateEndpointConn2 -Force
            Write-Host "Creating private DNS zone"
            $dnszone2 = New-AzPrivateDnsZone -ResourceGroupName $env:KeyVault_ResourceGroup -Name "privatelink.vaultcore.azure.net"
            Write-Host "Creating private DNS virtual link"
            #$vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:KeyVault_ResourceGroup -ZoneName "privatelink.vaultcore.azure.net" -Name "kv-virtual-link" -VirtualNetworkId $vnetwork.Id
            $vlink2 = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $env:KeyVault_ResourceGroup -ZoneName "privatelink.vaultcore.azure.net" -Name "${env:resource_prefix}kv${env:resource_suffix}-vl" -VirtualNetworkId $vnetwork.Id
            #$networkInterface2 = Get-AzResource -ResourceId $privateEndpoint2.NetworkInterfaces[0].Id -ApiVersion "2019-04-01"
            $networkInterface2 = Get-AzResource -ResourceId $privateEndpoint2.NetworkInterfaces[0] -ApiVersion "2019-04-01"
            foreach ($ipconfig in $networkInterface2.properties.ipConfigurations) {
            foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) {
            Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"
            $recordName = $fqdn.split('.',2)[0]
            Write-Host "Record Name is $recordName"
            $dnsZone = $fqdn.split('.',2)[1]
            Write-Host "DNZ Zone is $dnsZone"
            Write-Host "Creating new DNS record set"
            New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.vaultcore.azure.net" -ResourceGroupName $env:KeyVault_ResourceGroup -Ttl 600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)
            }
            }  

            $cg = @{
                Name = 'privatelink.vaultcore.azure.net'
                PrivateDnsZoneId = $dnszone2.ResourceId
            }
            Write-Host "Creating private DNS config"
            $config = New-AzPrivateDnsZoneConfig @cg
        
            ## Create the DNS zone group. ##
            $zg = @{
                ResourceGroupName = $env:ResouceGroup_Name
                #PrivateEndpointName = "kv-PEP" 
                PrivateEndpointName = "${env:resource_prefix}kv${env:resource_suffix}-pep"
                #Name = 'kvZoneGroup'
                Name = "${env:resource_prefix}kv${env:resource_suffix}-zg"
                PrivateDnsZoneConfig = $config
            }
            Write-Host "Creating private DNS zone group"
            New-AzPrivateDnsZoneGroup @zg   
        }
        else 
        {
            Write-Host "$env:resource_prefixkv$env:resource_suffix exists but is in soft-deleted state"
        }
    }
    #Write-Host "Remove Devops IP from KV Firewall"
    #Remove-AzKeyVaultNetworkRule -VaultName $env:KeyVault_Name -IpAddressRange $ip -VirtualNetworkResourceId $virtualNetwork -PassThru
}

$SP_Client_ID = ConvertTo-SecureString ${env:SP_Client_ID} -AsPlainText -Force
Write-Host "bbb $SP_Client_ID"
$SP_Object_ID = ConvertTo-SecureString ${env:SP_Object_ID} -AsPlainText -Force
Write-Host "ccc $SP_Object_ID"
$SP_Client_Secret = ConvertTo-SecureString ${env:SP_Client_Secret} -AsPlainText -Force
Write-Host "ddd $SP_Client_Secret"
$SP_Tenant_ID = ConvertTo-SecureString ${env:SP_Tenant_ID} -AsPlainText -Force
Write-Host "eee $SP_Tenant_ID"
$Synapse_DBPassword = ConvertTo-SecureString ${env:Synapse_SqlAdministratorPassword_secret} -AsPlainText -Force
Write-Host "fff $Synapse_DBPassword"
$VM_Password = ConvertTo-SecureString ${env:VM_Password} -AsPlainText -Force
Write-Host "hhh $VM_Password"


##########################Adding Secrets in KV###########################################
if ($env:KeyVault_AddSecret -eq "True") 
{
    Write-Host "add secrete to teh keyvault"
    $KeyVault = Get-AzKeyVault -VaultName $env:KeyVault_Name -ResourceGroupName $env:KeyVault_ResourceGroup -ErrorAction SilentlyContinue
    if($null -ne $KeyVault)
    {
    Write-Host "add secrete to the keyvault 1"
        #$KeyVault1 = Get-AzKeyVault -VaultName $env:KeyVault_Name -Location $env:ResourceGroup_Location -InRemovedState -ErrorAction SilentlyContinue
        #$KeyVault1 = Get-AzKeyVault -VaultName $env:KeyVault_Name -ResourceGroupName $env:KeyVault_ResourceGroup -InRemovedState -ErrorAction SilentlyContinue
        if ($null -ne $KeyVault) 
        {
    Write-Host "add secrete to the keyvault 2"
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

    #####################################################################
        }
        else 
        {
            Write-Host "$env:resource_prefixkv$env:resource_suffix exists but is in soft-deleted state"
        }
    }
}