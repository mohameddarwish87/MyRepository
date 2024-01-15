# This File defines the output that will be printed after terraform finish apply
output "rgname" {
  value = azurerm_resource_group.resourcegroup.id
}

output "tenant_id"{
  value = data.azurerm_client_config.current.tenant_id
}

output "account_id" {
  value = data.azurerm_client_config.current.client_id
}

output "object_id" {
  value = data.azurerm_client_config.current.object_id
}

output "Module_Path" {
  value = "${path.module}"
}
/*output "notebook_url" {
 value = databricks_notebook.this.url
}

output "cluster_url" {
 value = databricks_cluster.this.url
}

output "job_url" {
  value = databricks_job.this.url
}*/
/*output "instrumentation_key" {
  count = var.FunctionApp_CreateEnable == true ? 1:0
  value = azurerm_application_insights.AppInsights[0].instrumentation_key
  sensitive = true
}

output "app_id" {
  count = var.FunctionApp_CreateEnable == true ? 1:0
  value = azurerm_application_insights.AppInsights[0].app_id
}*/