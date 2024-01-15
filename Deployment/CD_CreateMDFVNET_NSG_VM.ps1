if($env:VNET_Enable -eq "True")
{
    Write-Host "Deploying inside VNET..."    
    if ($env:VNET_Create -eq "True") 
    {   
        Write-Host "Creating new VNET..."
        Write-Host "Configure the back-end subnet..."     
        $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $env:default_Subnet_Name -AddressPrefix $env:default_Subnet
        Write-Host "Create the Azure Bastion subnet..."
        $bastsubnetConfig = New-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -AddressPrefix $env:Bastion_Subnet 

        Write-Host "Create the virtual network..."
        $net = @{
            Name = "${env:resource_prefix}vnet${env:resource_suffix}"
            ResourceGroupName = $env:ResouceGroup_Name
            Location = $env:ResourceGroup_Location
            AddressPrefix = $env:VNET_AddressPrefix
            Subnet = $subnetConfig, $bastsubnetConfig
        }
        $vnet = New-AzVirtualNetwork @net
        Write-Host "Adding KeyVault, Web and Storage as Service Point to Subnet.."
        $SEP = @('Microsoft.KeyVault','Microsoft.Web','Microsoft.Storage')
        foreach($mySEP in $SEP){
        Write-Host "aa"
        $virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}vnet${env:resource_suffix}" |  Get-AzVirtualNetworkSubnetConfig  -Name $env:default_Subnet_Name 
        Write-Host "bb"
        $ServiceEndPoint = New-Object 'System.Collections.Generic.List[String]'
        Write-Host "cc"
        $VirtualNetwork.ServiceEndpoints | ForEach-Object { $ServiceEndPoint.Add($_.service)}
        Write-Host "dd"
        $ServiceEndPoint.Add($mySEP)
        Write-Host "ee"
        $virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}vnet${env:resource_suffix}"
        Write-Host "ee1"
        $virtualNetwork | Set-AzVirtualNetworkSubnetConfig -Name $env:default_Subnet_Name   -AddressPrefix $env:default_Subnet -ServiceEndpoint $ServiceEndPoint
        Write-Host "ff"
        $virtualNetwork | Set-AzVirtualNetwork
        Write-Host "gg"
        }
    }  
    if($env:Public_IP_Create -eq "True")  
    {  
        Write-Host "Creating the public IP address for the bastion host..."
        $ip = @{
            #Name = $env:Public_IP_Name#"datalake-vnet-vm01-ip"
            Name = "${env:resource_prefix}vnet${env:resource_suffix}-pip"
            ResourceGroupName = $env:ResouceGroup_Name
            Location = $env:ResourceGroup_Location
            Sku = "Standard"
            AllocationMethod = "Static"
            Zone = 1,2,3
        }
        $publicip = New-AzPublicIpAddress @ip
    }
    if($env:Bastion_Create -eq "True")
    { 
        Write-Host "Creating the bastion host..."
        $bastion = @{
            ResourceGroupName = $env:ResouceGroup_Name
            Name = "${env:resource_prefix}vnet${env:resource_suffix}-bas" #"vnet-bas01"
            PublicIpAddress = $publicip
            VirtualNetwork = $vnet
        }
        New-AzBastion @bastion -AsJob
    }
    if($env:NSG_Create -eq "True")
    {
      Write-Host "Creating Network Security Group..."
      $Params = @{
         #"Name"              = $env:NSG_Name
          "Name"              = "${env:resource_prefix}vnet${env:resource_suffix}-nsg"
          "ResourceGroupName" = $env:ResouceGroup_Name
          "Location"          = $env:ResourceGroup_Location
          }    
      $NSG = New-AzNetworkSecurityGroup @Params 
      Write-Host "11"
      #$NSG = Get-AzNetworkSecurityGroup -Name $env:NSG_Name -ResourceGroupName $env:ResouceGroup_Name
      $NSG = Get-AzNetworkSecurityGroup -Name "${env:resource_prefix}vnet${env:resource_suffix}-nsg" -ResourceGroupName $env:ResouceGroup_Name
      Write-Host "12"
      $Params = @{
        'Name'                     = 'ARM-ServiceTag'
        'NetworkSecurityGroup'     = $NSG
        'Protocol'                 = '*'
        'Direction'                = 'Outbound'
        'Priority'                 = 3000
        'SourceAddressPrefix'      = '*'
        'SourcePortRange'          = '*'
        'DestinationAddressPrefix' = 'AzureResourceManager'
        'DestinationPortRange'     = @('443')
        'Access'                   = 'Allow'
      }
      Add-AzNetworkSecurityRuleConfig @Params | Set-AzNetworkSecurityGroup
      Write-Host "13"
      $Params = @{
          'Name'                     = 'AzureFrontDoor.Frontend-ServiceTag'
          'NetworkSecurityGroup'     = $NSG
          'Protocol'                 = 'TCP'
          'Direction'                = 'Outbound'
          'Priority'                 = 3010
          'SourceAddressPrefix'      = '*'
          'SourcePortRange'          = '*'
          'DestinationAddressPrefix' = 'AzureFrontDoor.Frontend'
          'DestinationPortRange'     = @('443')
          'Access'                   = 'Allow'
        }
      Add-AzNetworkSecurityRuleConfig @Params | Set-AzNetworkSecurityGroup
      Write-Host "14"
      $Params = @{
          'Name'                     = 'AzureActiveDirectory-ServiceTag'
          'NetworkSecurityGroup'     = $NSG
          'Protocol'                 = 'TCP'
          'Direction'                = 'Outbound'
          'Priority'                 = 3020
          'SourceAddressPrefix'      = '*'
          'SourcePortRange'          = '*'
          'DestinationAddressPrefix' = 'AzureActiveDirectory'
          'DestinationPortRange'     = @('443')
          'Access'                   = 'Allow'
      }
      Add-AzNetworkSecurityRuleConfig @Params | Set-AzNetworkSecurityGroup
      Write-Host "15"
      $Params = @{
          'Name'                     = 'AzureMonitor-ServiceTag'
          'NetworkSecurityGroup'     = $NSG
          'Protocol'                 = 'TCP'
          'Direction'                = 'Outbound'
          'Priority'                 = 3030
          'SourceAddressPrefix'      = '*'
          'SourcePortRange'          = '*'
          'DestinationAddressPrefix' = 'AzureMonitor'
          'DestinationPortRange'     = @('443')
          'Access'                   = 'Allow'
      }
      Add-AzNetworkSecurityRuleConfig @Params | Set-AzNetworkSecurityGroup
    }
        Write-Host "16"
    if($env:VM_Create -eq "True")
    {
      Write-Host "Creating new VM..."
      ## Create the credential for the virtual machine. Enter a username and password at the prompt. ##
      #$cred = Get-Credential
      Write-Host "16.1"
      $User = $env:VM_Username
      Write-Host "16.2"
      $PWord = ConvertTo-SecureString ${env:VM_Password} -AsPlainText -Force
      Write-Host "password is $PWord"
      Write-Host "16.3"
      $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
      Write-Host "17"
      ## Place the virtual network into a variable. ##
      $vnet = Get-AzVirtualNetwork -Name "${env:resource_prefix}vnet${env:resource_suffix}" -ResourceGroupName $env:ResouceGroup_Name
      Write-Host "18"
      ## Create a network interface for the virtual machine. ##
      $nic = @{
          #Name = 'NicVM'
          Name = "${env:resource_prefix}dsvm${env:resource_suffix}-nic"
          ResourceGroupName = $env:ResouceGroup_Name
          Location = $env:ResourceGroup_Location
          Subnet = $vnet.Subnets[0]
      }
      Write-Host "18.1"
      $nicVM = New-AzNetworkInterface @nic
      Write-Host "19"
      ## Create the configuration for the virtual machine. ##
      $vm1 = @{
          VMName = $env:VM_Name 
          VMSize = 'standard_d4s_v3'#'Standard_DS1_v2'
      }
      $vm2 = @{
          ComputerName = $env:VM_Name
          Credential = $cred
      }
      $vm3 = @{
          PublisherName = 'microsoft-dsvm'
          Offer = 'dsvm-win-2019'
          Skus = 'winserver-2019'
          Version = 'latest'
      }
      Write-Host "19.1"
      $vmConfig = New-AzVMConfig @vm1 | Set-AzVMOperatingSystem -Windows @vm2 | Set-AzVMSourceImage @vm3 | Add-AzVMNetworkInterface -Id $nicVM.Id
      Write-Host "20"
      ## Create the virtual machine. ##
      New-AzVM -ResourceGroupName $env:ResouceGroup_Name -Location $env:ResourceGroup_Location -VM $vmConfig
      Write-Host "21"
    }
#    if($env:VM_Start_Install_SW -eq "True")
#    { 
#      Write-Host "Trying to start VM.."
#      Start-VM -Name $env:VM_Name   
#      $VM = Get-VM -ComputerName $env:VM_Name
#      while ($VM.state -ne "Running")
#      {
#        $VM = Get-VM -ComputerName $env:VM_Name
#          write-host "The VM is not on"
#          sleep 5
#      }   
#      Write-Host "VM is running now.."
#      Write-Host "Installing Azure packages..."
#      az vm run-command invoke  --command-id RunPowerShellScript --name $env:VM_Name -g $env:ResouceGroup_Name --scripts @Deployment/InstallSW.ps1
#      Write-Host "Installing Azure packages finished..."
#    }

}

