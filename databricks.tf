#This is working version of terraform that spins up databrics (workspace, cluser and instance pool). This has been created by Mohamed Darwish

#Creating databricks workspace
resource "azurerm_databricks_workspace" "workspace" {
  location            = var.ResourceGroup_Location
  name                = var.DatabricksName
  count = var.Databricks_Enable == true && var.VNET_Enable == false ? 1:0
  resource_group_name = var.ResouceGroup_Name
  sku                 = "premium"

}

data "databricks_node_type" "smallest" {
  depends_on = [azurerm_databricks_workspace.workspace]
  local_disk = true
}

data "databricks_spark_version" "latest_lts" {
  count = var.Databricks_Enable == true && var.VNET_Enable == false ? 1:0
  depends_on        = [azurerm_databricks_workspace.workspace]
  long_term_support = true
}

#Creating databricks instance pool
resource "databricks_instance_pool" "smallest_nodes" {
  count = var.Databricks_Enable == true && var.VNET_Enable == false ? 1:0
  instance_pool_name                    = "Smallest Nodes"
  min_idle_instances                    = 0
  max_capacity                          = 10
  node_type_id                          = "Standard_DS3_v2" # data.databricks_node_type.smallest.id #
  idle_instance_autotermination_minutes = 10
}


#Creating databricks cluster
resource "databricks_cluster" "shared_autoscaling" {
  count = var.Databricks_Enable == true && var.VNET_Enable == false ? 1:0
  depends_on              = [azurerm_databricks_workspace.workspace[0]]
  instance_pool_id        = databricks_instance_pool.smallest_nodes[0].id
  cluster_name            = "Shared Autoscaling"
  spark_version           = data.databricks_spark_version.latest_lts[0].id
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

#data "databricks_current_user" "me" {}

#creating notebook inside databricks with line code print('Hello Databricks')
resource "databricks_notebook" "this" {
  count = var.Databricks_Enable == true && var.VNET_Enable == false ? 1:0
  depends_on = [azurerm_databricks_workspace.workspace[0]]
  language = var.notebook_language
  path = var.notebook_path_RetreiveBabyNames
  content_base64 = base64encode("print('Hello Databricks')")
  #source   = "./${var.notebook_filename}"
}

#Creating workflow job
resource "databricks_job" "this" {
  count = var.Databricks_Enable == true && var.VNET_Enable == false ? 1:0
  depends_on = [azurerm_databricks_workspace.workspace[0]]
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