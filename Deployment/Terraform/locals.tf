# Below we define local variables
locals{
  container_names = [var.StorageAccount_LandingContainer, var.StorageAccount_StagingContainer, var.StorageAccount_RawContainer, var.StorageAccount_CuratedContainer,"system"]
  filesystemName = "system"
  localSrcFile =  "../../Resources/ADLS/Functions/ConvertToDelta.py"
  dirname = "Functions/"
  #secret_names = [var.KeyVault_SP_ClientId, var.KeyVault_SP_ClientSecret, var.KeyVault_SP_TenantId, var.KeyVault_SP_ObjectId, var.KeyVault_Synapse_DBPassword ]
  #secret_values = [var.SP_Client_ID, var.SP_Client_Secret, var.SP_Tenant_ID, var.SP_Object_ID, var.Synapse_SqlAdministratorPassword_secret ]
  #Admin_Object_IDs = [data.azurerm_client_config.current.object_id,"3ce048ad-c358-4be6-98c7-ad5b45042078",azurerm_linux_function_app.FunctionApp[0].identity.0.principal_id, azurerm_synapse_workspace.synapse[0].identity.0.principal_id ]
  #Admin_Object_IDs = [data.azurerm_client_config.current.object_id,"3ce048ad-c358-4be6-98c7-ad5b45042078",azurerm_linux_function_app.FunctionApp[0].identity.0.principal_id]
  Admin_Object_IDs = ["010bc095-7af8-4b59-a3ba-7aa5d9765af1"]#,"02a679e9-1aaf-453c-a6bd-80846c1f6d15"]#, "6c8d42df-72b8-470f-9c4e-c2e0efc5912f"]
  #Admin_Object_IDs2 = [data.azurerm_client_config.current.object_id,"010bc095-7af8-4b59-a3ba-7aa5d9765af1",azurerm_linux_function_app.FunctionApp[0].identity.0.principal_id,azurerm_synapse_workspace.synapse[0].identity.0.principal_id] #,"02a679e9-1aaf-453c-a6bd-80846c1f6d15"]#, "6c8d42df-72b8-470f-9c4e-c2e0efc5912f"]
  SP_CLIENT_ID = "f2df94b0-08a8-4884-9583-9d50bb365f4b"
  SP_CLIENT_SECRET = "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk"
  SP_TENANT_ID = "4cda32ca-6b19-4051-8b93-85889e7947dd"
  Admin_Object_IDs2 = {
    one = data.azurerm_client_config.current.object_id,
    two = "010bc095-7af8-4b59-a3ba-7aa5d9765af1",
    three = var.FunctionApp_CreateEnable == true  && var.VNET_Enable == false ? azurerm_linux_function_app.FunctionApp[0].identity.0.principal_id : null,
    #four = var.Synapse_Enable == true && var.VNET_Enable == false ? azurerm_synapse_workspace.synapse[0].identity.0.principal_id : null
    three = var.FunctionApp_CreateEnable == true  && var.VNET_Enable == true ? azurerm_linux_function_app.FunctionApp_VNET[0].identity.0.principal_id : null
    #four = var.Synapse_Enable == true && var.VNET_Enable == true ? azurerm_synapse_workspace.synapse_vnet[0].identity.0.principal_id : null
  }
  Admin_Object_IDs3 = {
    one = data.azurerm_client_config.current.object_id,
    two = "010bc095-7af8-4b59-a3ba-7aa5d9765af1",
    four = var.Synapse_Enable == true && var.VNET_Enable == false ? azurerm_synapse_workspace.synapse[0].identity.0.principal_id : null,
    four = var.Synapse_Enable == true && var.VNET_Enable == true ? azurerm_synapse_workspace.synapse_vnet[0].identity.0.principal_id : null
  }
  #ifconfig_co_json = jsondecode(data.http.my_public_ip.body)
}

# Below we define data azurerm_client_config to use it by other resources to fetch objectid, client_id and tenant_id and subscription id of Service principal
data "azurerm_client_config" "current" {}
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

data "http" "my_public_ip" {
  url = "https://ifconfig.co/ip"
}
/*data "http" "my_public_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}*/

/*
locals {
  ifconfig_co_json = jsondecode(data.http.my_public_ip.body)
}*/

#data "databricks_current_user" "me" {}
/*data "databricks_current_user" "me" {
  azure_workspace_resource_id = azurerm_databricks_workspace.workspace.id
  azure_client_id = "465186df-2d55-4505-8fcc-6336690c6414"
  azure_client_secret = "xXY8Q~EpFlzIhXL6Hj9TtHuHYgyD6k~ufJIAUdBo"
  azure_tenant_id = "b1ac35c5-fd11-43ba-a811-f82cc883731f"
}*/
# Create the cluster with the "smallest" amount
# of resources allowed.

/*data "databricks_current_user" "me" {}
# Create the cluster with the "smallest" amount
# of resources allowed.
data "databricks_node_type" "smallest" {
  local_disk = true
}

# Use the latest Databricks Runtime
# Long Term Support (LTS) version.
data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}*/