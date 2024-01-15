# This file contains definition and creation of azure functions, service plan and App insights
# we also do deployment of python code to azure functions

#creation of Service Plan with condition if variable FunctionApp_CreateEnable set to true
resource "azurerm_service_plan" "ServicePlan" {
  count = var.ServicePlan_AppInsights_CreateEnable == true && var.VNET_Enable == false? 1:0
  name                = "${var.FunctionApp_Name}-SP"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

#creation of application insights with condition if variable FunctionApp_CreateEnable set to true
resource "azurerm_application_insights" "AppInsights" {
  count = var.ServicePlan_AppInsights_CreateEnable == true  && var.VNET_Enable == false ? 1:0
  name                = "cg-fun-terr-appinsights"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  application_type    = "web"
}

resource "azurerm_storage_account" "functionappstorage" {
  name                     = replace("${var.FunctionApp_Name}storage","-","")#var.StorageAccount_Name
  #resource_group_name      = azurerm_resource_group.example.name
  count = var.FunctionApp_CreateEnable == true && var.VNET_Enable == false? 1:0
  resource_group_name      = azurerm_resource_group.resourcegroup.name
  location                 = azurerm_resource_group.resourcegroup.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  #is_hns_enabled = false
  account_kind = "Storage"
  min_tls_version = "TLS1_2"
  tags = var.tags
}

#creation of function app with condition if variable FunctionApp_CreateEnable set to true
# we also added our own custom site config
resource "azurerm_linux_function_app" "FunctionApp" {
  count = var.FunctionApp_CreateEnable == true  && var.VNET_Enable == false? 1:0
  name                       = var.FunctionApp_Name
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location

  storage_account_name       = azurerm_storage_account.functionappstorage[0].name
  storage_account_access_key = azurerm_storage_account.functionappstorage[0].primary_access_key
  service_plan_id            = azurerm_service_plan.ServicePlan[0].id

  site_config {
    application_insights_key               = azurerm_application_insights.AppInsights[0].instrumentation_key
    application_insights_connection_string = azurerm_application_insights.AppInsights[0].connection_string
    application_stack {
      python_version = "3.9"
    }
  }
  app_settings={
    AzureWebJobsStorage = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.functionappstorage[0].name};EndpointSuffix=core.windows.net;AccountKey=${azurerm_storage_account.functionappstorage[0].primary_access_key}"
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.functionappstorage[0].name};EndpointSuffix=core.windows.net;AccountKey=${azurerm_storage_account.functionappstorage[0].primary_access_key}"
    MDDF_Storage = "DefaultEndpointsProtocol=https;AccountName=${var.StorageAccount_Name};EndpointSuffix=core.windows.net;AccountKey=${azurerm_storage_account.storage[0].primary_access_key}"
    WEBSITE_CONTENTSHARE = var.FunctionApp_Name
    FUNCTIONS_EXTENSION_VERSION = "~4"
    PYTHON_ENABLE_WORKER_EXTENSIONS = "1"
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.AppInsights[0].instrumentation_key
    FUNCTIONS_WORKER_RUNTIME = "python"
    KeyVault_Name = var.KeyVault_Name
    StorageAccount_CuratedContainer = var.StorageAccount_CuratedContainer
    StorageAccount_LandingContainer = var.StorageAccount_LandingContainer
    StorageAccount_StagingContainer = var.StorageAccount_StagingContainer
    StorageAccount_RawContainer = var.StorageAccount_RawContainer
    StorageAccount_Name = var.StorageAccount_Name
    Synapse_Name = var.Synapse_Name
    Synapse_PoolName = var.Synapse_PoolName
    FunctionApp_Name = var.FunctionApp_Name
    #SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    #WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "DefaultEndpointsProtocol=https;AccountName=${var.StorageAccount_Name};EndpointSuffix=core.windows.net;AccountKey=${azurerm_storage_account.storage[0].primary_access_key}"
    #linux_fx_version = "python|3.9"
  }
  identity {
    type = "SystemAssigned"
  }
  depends_on  = [
      azurerm_storage_account.functionappstorage 
  ]

}

#data "archive_file" "function_archive"{
#  type = "zip"
#  source_dir = "${path.module}/../../Resources/function"
#  output_path = "${path.module}/../../Resources/function33.zip"
  
#}
# Below we deploy python code to azure function app by running powershell to zip the code and publish it

#data "external" "function_archive"{
#  program = ["./zip.sh","../../Resources/function33.zip","../../Resources/function"]
#}
/*data "archive_file" "function_zip"{
  type = "zip"
  source_file  = "${path.module}/../../Resources/function"
  output_path = "${path.module}/../../Resources/function29.zip" 
}*/
resource "null_resource" "functions" {
   count = var.FunctionApp_ConfigureEnable == true && var.FunctionApp_CreateEnable == true ? 1:0
   triggers = {
    "version" = var.function_update_version
   }
   #"../../Resources/function29.zip"
   provisioner "local-exec" {
    #command = "az functionapp deployment source config-zip -g ${azurerm_resource_group.resourcegroup.name} -n ${var.FunctionApp_Name} --src ${var.Functionapp_zippath}" 
#    command = "Compress-Archive -Path  ${var.Functionapp_sourcepath} -Update -DestinationPath ${var.Functionapp_zippath};Publish-AzWebapp -ResourceGroupName ${azurerm_resource_group.resourcegroup.name} -Name ${var.FunctionApp_Name} -ArchivePath ${var.Functionapp_zippath} -Force"
    command = "7z a -tzip ${var.Functionapp_zippath} ${var.Functionapp_sourcepath};Publish-AzWebapp -ResourceGroupName ${azurerm_resource_group.resourcegroup.name} -Name ${var.FunctionApp_Name} -ArchivePath ${var.Functionapp_zippath} -Force"
    interpreter = ["PowerShell", "-Command"]
   }

  depends_on  = [
      azurerm_linux_function_app.FunctionApp #,data.archive_file.function_zip
  ]
}

