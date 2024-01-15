#This is working version of terraform that spins up databrics (workspace, cluser and instance pool). This has been created by Mohamed Darwish

#Creating databricks workspace
resource "azurerm_databricks_workspace" "workspace_vnet" {
  location            = var.ResourceGroup_Location
  name                = var.DatabricksName
  count = var.Databricks_Enable == true && var.VNET_Enable == true ? 1:0
  resource_group_name = var.ResouceGroup_Name
  #managed_resource_group_name = "${var.DatabricksName}-managed-private-endpoint"
  sku                 = "premium"
  public_network_access_enabled = false
  network_security_group_rules_required = "NoAzureDatabricksRules"
  #provider = databricks.second
  custom_parameters {
  public_subnet_name = var.Databricks_Public_Subnet_Name
  private_subnet_name = var.Databricks_Private_Subnet_Name
  virtual_network_id = azurerm_virtual_network.VNET[0].id
  public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.nsga_public.id
  private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.nsga_private.id
  no_public_ip        = true
  

  }

}

resource "azurerm_network_security_group" "nsg" {
    name = "${var.DatabricksName}-qa-databricks-nsg"
    resource_group_name = azurerm_resource_group.resourcegroup.name
    location= azurerm_resource_group.resourcegroup.location
}

# resource "azurerm_network_security_group" "nsg2" {
#     name = "${var.DatabricksName}-qa-databricks-nsg2"
#     resource_group_name = azurerm_resource_group.resourcegroup.name
#     location= azurerm_resource_group.resourcegroup.location
# }

resource "azurerm_subnet_network_security_group_association" "nsga_public" {
    network_security_group_id = azurerm_network_security_group.nsg.id
    subnet_id = azurerm_subnet.DatabricksPublicSubnet.id
}

resource "azurerm_subnet_network_security_group_association" "nsga_private" {
    network_security_group_id = azurerm_network_security_group.nsg.id
    subnet_id = azurerm_subnet.DatabricksPrivateSubnet.id
}

resource "azurerm_private_endpoint" "db-pep-api" {
  name                = "${var.DatabricksName}-pep-api"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  subnet_id           = azurerm_subnet.DefaultSubnet.id

  private_service_connection {
    name                           = "${var.DatabricksName}-pepc-api"
    private_connection_resource_id = azurerm_databricks_workspace.workspace_vnet[0].id
    subresource_names              = ["databricks_ui_api"]
    is_manual_connection = false
  }
  private_dns_zone_group {
    name                 = "${var.DatabricksName}-zgdbapi"
    private_dns_zone_ids = [azurerm_private_dns_zone.db-dnszone.id]
  }
}

resource "azurerm_private_dns_zone" "db-dnszone" {
  #depends_on = [azurerm_private_endpoint.db-pep]
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}



# resource "azurerm_private_dns_cname_record" "db-dns-record" {
#   name                = azurerm_databricks_workspace.workspace_vnet[0].workspace_url
#   zone_name           = azurerm_private_dns_zone.db-dnszone.name
#   resource_group_name = azurerm_resource_group.resourcegroup.name
#   ttl                 = 300
#   #record              = "eastus2-c2.azuredatabricks.net"
#   record              = "${var.DatabricksName}.azuredatabricks.net"
# }



resource "azurerm_private_dns_zone_virtual_network_link" "db-api-vl" {
 name                  = "${var.DatabricksName}-api-vl"
 resource_group_name   = azurerm_resource_group.resourcegroup.name
 private_dns_zone_name = azurerm_private_dns_zone.db-dnszone.name
 virtual_network_id    = azurerm_virtual_network.VNET[0].id
}


resource "azurerm_network_interface" "db-api-nic" {
  name                = "${var.DatabricksName}-api-nic"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location

  ip_configuration {
    name                          = "${var.DatabricksName}-api-ipconfig"
    subnet_id                     = azurerm_subnet.DefaultSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_private_endpoint" "db-pep-browser" {
  name                = "${var.DatabricksName}-pep-b"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  subnet_id           = azurerm_subnet.DefaultSubnet.id

  private_service_connection {
    name                           = "${var.DatabricksName}-pepc-b"
    private_connection_resource_id = azurerm_databricks_workspace.workspace_vnet[0].id
    subresource_names              = ["browser_authentication"]
    is_manual_connection = false
  }
  private_dns_zone_group {
    name                 = "${var.DatabricksName}-zgdbb"
    private_dns_zone_ids = [azurerm_private_dns_zone.db-dnszone.id]
  }
}

# resource "azurerm_private_dns_zone" "db-dnszone-browser" {
#   #depends_on = [azurerm_private_endpoint.db-pep]
#   name                = "privatelink.azuredatabricks.net"
#   resource_group_name = azurerm_resource_group.resourcegroup.name
# }


# resource "azurerm_private_dns_zone_virtual_network_link" "db-b-vl" {
#  name                  = "${var.DatabricksName}-b-vl"
#  resource_group_name   = azurerm_resource_group.resourcegroup.name
#  private_dns_zone_name = azurerm_private_dns_zone.db-dnszone.name
#  virtual_network_id    = azurerm_virtual_network.VNET[0].id
# }


# resource "azurerm_network_interface" "db-b-nic" {
#   name                = "${var.DatabricksName}-b-nic"
#   resource_group_name = azurerm_resource_group.resourcegroup.name
#   location            = azurerm_resource_group.resourcegroup.location

#   ip_configuration {
#     name                          = "${var.DatabricksName}-b-ipconfig"
#     subnet_id                     = azurerm_subnet.DefaultSubnet.id
#     private_ip_address_allocation = "Dynamic"
#   }
# }

data "databricks_node_type" "smallest_vnet" {
  depends_on = [azurerm_databricks_workspace.workspace_vnet[0]]
  local_disk = true
  provider = databricks.second
}

data "databricks_spark_version" "latest_lts_vnet" {
  # count = var.Databricks_Enable == true && var.VNET_Enable == true ? 1:0
  depends_on        = [azurerm_databricks_workspace.workspace_vnet[0]]
  # long_term_support = true
  provider = databricks.second
  #provider = { databricks.second}

}

#Creating databricks instance pool
resource "databricks_instance_pool" "smallest_nodes_vnet" {
  depends_on = [azurerm_databricks_workspace.workspace_vnet[0]]

   provider = databricks.second
#   count = var.Databricks_Enable == true && var.VNET_Enable == true ? 1:0
   instance_pool_name                    = "Smallest Nodes"
    min_idle_instances                    = 0
    max_capacity                          = 10
    node_type_id                          = "Standard_DS3_v2" # data.databricks_node_type.smallest.id #
   idle_instance_autotermination_minutes = 10
 }


#Creating databricks cluster
resource "databricks_cluster" "shared_autoscaling_vnet" {
  count = var.Databricks_Enable == true && var.VNET_Enable == true ? 1:0
  depends_on              = [azurerm_databricks_workspace.workspace_vnet[0]]
  instance_pool_id        = databricks_instance_pool.smallest_nodes_vnet.id
  cluster_name            = "Shared Autoscaling"
  spark_version           = data.databricks_spark_version.latest_lts_vnet.id
  provider = databricks.second
  #node_type_id            = "Standard_DS3_v2"# data.databricks_node_type.smallest.id
  autotermination_minutes = 20
  autoscale {
    min_workers = 1
    max_workers = 50
  }
  spark_conf = {
    "spark.databricks.io.cache.enabled" : true
  }
}

  #  data "databricks_current_user" "me" {}

  #  creating notebook inside databricks with line code print('Hello Databricks')
resource "databricks_notebook" "this_vnet" {
  count = var.Databricks_Enable == true && var.VNET_Enable == true ? 1:0
  provider = databricks.second
  depends_on = [azurerm_databricks_workspace.workspace_vnet[0]]
  language = var.notebook_language
  path = var.notebook_path_RetreiveBabyNames
  content_base64 = base64encode("print('Hello Databricks')")
  #source   = "./${var.notebook_filename}"
}

    #Creating workflow job
resource "databricks_job" "this_vnet" {
  count = var.Databricks_Enable == true && var.VNET_Enable == true ? 1:0
  depends_on = [azurerm_databricks_workspace.workspace_vnet[0]]
  provider = databricks.second
  name = var.job_name
  timeout_seconds = 3060
  max_retries = 1
  max_concurrent_runs = 1
  job_cluster {
    job_cluster_key = "j"
    new_cluster {
      num_workers = 1
      spark_version = "7.3.x-scala2.12"
      node_type_id = "Standard_DS3_v2"
    }
  }
  #existing_cluster_id = databricks_cluster.this.cluster_id
  #notebook_task {
  #  notebook_path = databricks_notebook.this.path
  #}
  task {
    task_key = "RetrieveBabyNames"
    new_cluster {
      num_workers = 1
      spark_version = "7.3.x-scala2.12"
      node_type_id = "Standard_DS3_v2"
    }
    notebook_task {
      notebook_path = var.notebook_path_RetreiveBabyNames  #databricks_notebook.this.path
    }
  }
  email_notifications {
    #on_success = [ data.databricks_current_user.me.user_name ]
    #on_failure = [ data.databricks_current_user.me.user_name ]
    no_alert_for_skipped_runs = true
  }
}