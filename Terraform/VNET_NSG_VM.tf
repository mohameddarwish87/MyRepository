
resource "azurerm_network_security_group" "NSG" {
  name                = var.NSG_Name
  count = var.VNET_Enable == true ? 1:0
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  depends_on = [azurerm_virtual_network.VNET[0]]
  security_rule {
    name                       = "ARM-ServiceTag"
    priority                   = 3000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureResourceManager"
  }

  security_rule {
    name                       = "AzureFrontDoor.Frontend-ServiceTag"
    priority                   = 3010
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureFrontDoor.Frontend"
  }
  security_rule {
    name                       = "AzureActiveDirectory-ServiceTag"
    priority                   = 3020
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureActiveDirectory"
  }
  security_rule {
    name                       = "AzureMonitor-ServiceTag"
    priority                   = 3030
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureMonitor"
  }
}

resource "azurerm_virtual_network" "VNET" {
  name                = var.VNET_Name
  count = var.VNET_Enable == true ? 1:0
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  address_space       = var.VNET_AddressSpace  #["10.0.0.0/16"]
  #dns_servers         = #["10.0.0.4", "10.0.0.5"]
/*
  subnet {
    name           =  var.default_Subnet_Name #"subnet1"
    address_prefix =  var.default_Subnet #"10.0.1.0/24"
  }

  subnet {
    name           = "AzureBastionSubnet"
    address_prefix = var.Bastion_Subnet #"10.0.2.0/24"
    security_group = azurerm_network_security_group.NSG.id
  }*/

}

resource "azurerm_subnet" "DefaultSubnet" {
  name                 = var.default_Subnet_Name
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.VNET[0].name
  #address_prefixes     = "[${var.default_Subnet}]" #["10.0.1.0/24"]
  address_prefixes     = var.default_Subnet #["10.0.1.0/24"]
  service_endpoints = ["Microsoft.Storage","Microsoft.KeyVault","Microsoft.Web"]
  depends_on = [azurerm_virtual_network.VNET[0]]

}

resource "azurerm_subnet" "BastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.VNET[0].name
  #address_prefixes     = "[${var.Bastion_Subnet}]" #["10.0.1.0/24"]
  address_prefixes     = var.Bastion_Subnet #["10.0.1.0/24"]
  depends_on = [azurerm_virtual_network.VNET[0]]

}

resource "azurerm_subnet" "FunctionSubnet" {
  name                 = var.Functionapp_OutboundSubnet_Name
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.VNET[0].name
  #address_prefixes     = "[${var.Bastion_Subnet}]" #["10.0.1.0/24"]
  address_prefixes     = var.Function_Subnet #["10.0.1.0/24"]
  #service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "FunctionOutboundServiceDelegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        #"Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
  depends_on = [azurerm_virtual_network.VNET[0]]

}

resource "azurerm_subnet" "DatabricksPublicSubnet" {
  name                 = var.Databricks_Public_Subnet_Name
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.VNET[0].name
  #address_prefixes     = "[${var.default_Subnet}]" #["10.0.1.0/24"]
  address_prefixes     = var.Databricks_Public_Subnet #["10.0.1.0/24"]
  #service_endpoints = ["Microsoft.Storage","Microsoft.KeyVault","Microsoft.Web"]
    delegation {
    name = "DatabricksPublicSubnetDelegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        #"Microsoft.Network/virtualNetworks/subnets/action"
      # "Microsoft.Network/virtualNetworks/subnets/join/action",
      # "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      # "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
  depends_on = [azurerm_virtual_network.VNET[0]]

}

resource "azurerm_subnet" "DatabricksPrivateSubnet" {
  name                 = var.Databricks_Private_Subnet_Name
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.VNET[0].name
  #address_prefixes     = "[${var.default_Subnet}]" #["10.0.1.0/24"]
  address_prefixes     = var.Databricks_Private_Subnet #["10.0.1.0/24"]
  delegation {
    name = "DatabricksPrivateSubnetDelegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        #"Microsoft.Network/virtualNetworks/subnets/action"
      # "Microsoft.Network/virtualNetworks/subnets/join/action",
      # "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      # "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
  #service_endpoints = ["Microsoft.Storage","Microsoft.KeyVault","Microsoft.Web"]
  depends_on = [azurerm_virtual_network.VNET[0]]

}

resource "azurerm_public_ip" "PublicIP" {
  
  name                = "${var.VNET_Name}-pip"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  allocation_method   = "Static"
  sku = "Standard"
  depends_on = [azurerm_virtual_network.VNET[0]]

}

resource "azurerm_bastion_host" "bastion" {
  name                = var.Bastion_Name
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  depends_on = [azurerm_virtual_network.VNET[0]]

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.BastionSubnet.id
    public_ip_address_id = azurerm_public_ip.PublicIP.id
  }
}
##############VM Creation####################
resource "azurerm_network_interface" "NIC" {
  name                = "${var.VM_Name}-nic"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "${var.VM_Name}-nic-config" #"testconfiguration1"
    subnet_id                     = azurerm_subnet.DefaultSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}



resource "azurerm_virtual_machine" "VM" {
  name                  = var.VM_Name
  depends_on = [azurerm_virtual_network.VNET[0]]
  location              = azurerm_resource_group.resourcegroup.location
  resource_group_name   = azurerm_resource_group.resourcegroup.name
  network_interface_ids = [azurerm_network_interface.NIC.id]
  vm_size               = "standard_d4s_v3"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
   delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "microsoft-dsvm" #"Canonical"
    offer     = "dsvm-win-2019"  #"0001-com-ubuntu-server-jammy"
    sku       = "winserver-2019"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.VM_Name}-osdisk" #"myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = var.VM_Name #"hostname"
    admin_username = var.VM_Username
    admin_password = var.VM_Password
  }
  os_profile_windows_config {
    
  }

}