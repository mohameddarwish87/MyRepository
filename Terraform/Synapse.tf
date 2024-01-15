# This file creates synapse workspace, spark pool, synape firewall and give permissions to different people and azure resources

# Below we create adls file system from storage account to be used by synapse as main storage for it
resource "azurerm_storage_data_lake_gen2_filesystem" "adls" {
  count = var.Synapse_Enable == true && var.VNET_Enable == false ? 1:0
  name               = "cg-adls"
  storage_account_id = azurerm_storage_account.storage[0].id
}


# Below we create synapse workspace based on condition Synapse_Enable
resource "azurerm_synapse_workspace" "synapse" {
  count = var.Synapse_Enable == true && var.VNET_Enable == false ? 1:0
  #count = 0
  name                                 = var.Synapse_Name
  resource_group_name                  = azurerm_resource_group.resourcegroup.name
  location                             = azurerm_resource_group.resourcegroup.location
  #storage_account_name                 = azurerm_storage_account.storage[0].name
  #file_system                          = var.StorageAccount_LandingContainer
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.adls[0].id
  sql_administrator_login              = var.Synapse_SqlAdministratorLogin
  # Below lookup function return value of key synapse-serverless-db-sqladminuser-password from map secret-maps
  sql_administrator_login_password     = lookup(var.secret_maps,"synapse-serverless-db-sqladminuser-password","NotFound")
  tags = var.tags
  aad_admin {
    login     = "AzureAD Admin"
    object_id = data.azurerm_client_config.current.object_id
    tenant_id = data.azurerm_client_config.current.tenant_id
  }

  identity {
    type = "SystemAssigned"
  }
  # Below we configure git of synapse to our azure devops repo
  azure_devops_repo {
    account_name = "Capgemini" #"empired"
    project_name = "Platforms" #"Empired-Data-AI-Integration"
    branch_name = "master" #"MDF_Default_Terrform"
    repository_name = var.azure_devops_repo
    root_folder = "/Resources/Synapse"
    tenant_id = lookup(var.secret_maps,"intergen-adls-tenantid","NotFound")
    #last_commit_id = "32ddfc91914582d35c47fade7ae866ef80954119"
  
  }
  # lifecycle for terraform to ignore any changes to azure_devops_repo block
  lifecycle {
    ignore_changes = [azure_devops_repo]
  }

  depends_on = [azurerm_storage_account.storage[0]]
}

# Below we create synapse spark pool based on condition Synapse_Enable
resource "azurerm_synapse_spark_pool" "SynapseSpark" {
  count = var.Synapse_Enable == true && var.VNET_Enable == false? 1:0
  name                 = var.Synapse_PoolName
  synapse_workspace_id = azurerm_synapse_workspace.synapse[0].id
  node_size_family     = "MemoryOptimized"
  node_size            = "Small"
  cache_size           = 100

  auto_scale {
    max_node_count = 50
    min_node_count = 3
  }

  auto_pause {
    delay_in_minutes = var.Synapse_ShutDown_Time
  }
  depends_on = [azurerm_synapse_workspace.synapse[0]]
  /*library_requirement {
    content  = <<EOF
appnope==0.1.0
beautifulsoup4==4.6.3
EOF
    filename = "requirements.txt"
  }*/

  /*spark_config {
    content  = <<EOF
spark.shuffle.spill                true
EOF
    filename = "config.txt"
  }*/

}
# Below we create synapse firewall and make it AllowAll for all IPs and it is also based on condition Synapse_Enable
resource "azurerm_synapse_firewall_rule" "devOpsIP" {
count = var.Synapse_Enable == true && var.VNET_Enable == false? 1 : 0
#resource_group_name = azurerm_resource_group.resourcegroup.name
name = "AllowAll"
synapse_workspace_id = azurerm_synapse_workspace.synapse[0].id
start_ip_address = "${chomp(data.http.myip.response_body)}" #"151.210.130.235" #"0.0.0.0"
end_ip_address = "${chomp(data.http.myip.response_body)}"   #"151.210.130.235" #"255.255.255.255"
depends_on = [azurerm_synapse_workspace.synapse[0]]
}

# Below 2 resources is for terraform to wait 60 second after applying firewall rule for it to take effect
resource "time_sleep" "wait_some_seconds" {
  count = var.Synapse_Enable == true && var.VNET_Enable == false? 1 : 0
  depends_on = [azurerm_synapse_firewall_rule.devOpsIP]
  triggers = {
    "version" = var.synapse_update_version
   }
  create_duration = "180s"
}

resource "azurerm_synapse_sql_pool" "sqlpool" {
  name                = "serverlessdb"
  #resource_group_name = azurerm_resource_group.resourcegroup.name
  count = var.Synapse_Enable == true && var.VNET_Enable == false ? 1:0
  synapse_workspace_id = azurerm_synapse_workspace.synapse[0].id
  sku_name             = "DW100c"
  create_mode          = "Default"
  storage_account_type = "GRS"
}
/*resource "time_sleep" "wait_some_seconds2" {
  count = var.Synapse_Enable == true ? 1 : 0
  depends_on = [time_sleep.wait_some_seconds]

  create_duration = "90s"
}
resource "time_sleep" "wait_some_seconds3" {
  count = var.Synapse_Enable == true ? 1 : 0
  depends_on = [time_sleep.wait_some_seconds2]

  create_duration = "90s"
}*/
#resource "null_resource" "next" {
#  depends_on = [time_sleep.wait_90_seconds]
#}


/*
resource "azuredevops_project" "ado_project" {
  name               = "Empired-Data-AI-Integration"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"
}

resource "azuredevops_git_repository" "ado_import" {
  project_id = azuredevops_project.ado_project.id
  name       = "ado Import Repository"
  initialization {
    init_type   = "Import"
    source_type = "Git"
    source_url  = "https://empired@dev.azure.com/empired/Empired-Data-AI-Integration/_git/intergen-metadata-driven-framework"
  }
  depends_on = [azurerm_synapse_workspace.synapse[0]]
}*/