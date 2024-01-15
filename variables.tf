#This file defines the variables used in terraform and been initialised in demo.auto.tfvars
variable "ResouceGroup_Name" {
    //default = "AzureRMResourcegroup"
    description = "This is a resource group"
}

variable "ResourceGroup_Location" {
    default = "Australia East"
}

variable "StorageAccount_Name" {


}

variable "ResouceGroup_Enable" {

}

variable "tags" {
type = map
}

variable "StorageAccount_HierarchyEnable" {

}

variable "StorageAccount_SKU" {

}
variable "StorageAccount_Terraform_SKU"{

}

variable "StorageAccount_CuratedContainer"{

}
variable "StorageAccount_Enable"{

}
variable "StorageAccount_LandingContainer"{

}
variable "StorageAccount_RawContainer"{

}
variable "StorageAccount_StagingContainer"{

}
variable "KeyVault_Name"{

}
variable "KeyVault_Enable"{

}
variable "Functionapp_OutboundSubnet_Name"{

}
variable "Function_Subnet"{

}
variable "Databricks_Public_Subnet"{
  
}
variable "Databricks_Private_Subnet"{
  
}
variable "Databricks_Public_Subnet_Name"{

}
variable "Databricks_Private_Subnet_Name"{

}
variable "RBAC_Enable"{

}
variable "Subscription_Name"{
}
#variable "databricks_name"{

#}
/*variable "KeyVault_SP_ClientId"{

}
variable "KeyVault_SP_ClientSecret"{

}
variable "KeyVault_SP_ObjectId"{

}
variable "KeyVault_SP_TenantId"{

}
variable "KeyVault_Synapse_DBPassword"{

}
variable "SP_Client_ID"{

}
variable "SP_Client_Secret"{

}
variable "SP_Object_ID"{

}
variable "SP_Tenant_ID" {

}*/

variable "secret_maps" {
    type = map(string)

}

variable "FunctionApp_CreateEnable"{

}
variable "ServicePlan_AppInsights_CreateEnable"{

}
variable "FunctionApp_Name"{

}

variable "FunctionApp_ConfigureEnable"{

}
variable "Functionapp_zippath"{

}
variable "Functionapp_sourcepath"{
    
}
variable "Synapse_Name"{

}
variable "Synapse_PoolName"{
    
}
variable "Synapse_Enable"{

}
variable "Synapse_ServerlessDB"{

}
variable "Synapse_ShutDown_Time"{

}
variable "Synapse_SqlAdministratorLogin"{

}
#variable "Synapse_SqlAdministratorPassword_secret" {

#}
variable "azure_devops_repo" {

}

variable "function_update_version"{
    type = string
    description = "This field is used to determine whether a new versio of the powershell script needs to be executed"
}
variable "synapse_update_version"{
    type = string
    description = "This field is used to determine whether you want to apply sleep time after firewall creation"
}
variable "notebook_filename" {
  description = "The notebook's filename."
  type        = string
}

variable "notebook_language" {
  description = "The language of the notebook."
  type        = string
}
variable "notebook_subdirectory" {
  description = "A name for the subdirectory to store the notebook."
  type        = string
  default     = "Terraform"
}

variable "databricks_host" {

}
variable "notebook_path_RetreiveBabyNames"{

}
variable "databricks_connection_profile"{
  
}
variable "NSG_Name"{
  
}
variable "VNET_Enable"{
  
} 
variable "VNET_Name"{
  
}
variable "VNET_AddressSpace"{
  
}
variable "default_Subnet_Name"{
  
}
variable "default_Subnet"{
  
}
variable "Bastion_Subnet"{
  
}
variable "Bastion_Name"{
  
}
variable "VM_Name"{
  
}
variable "VM_Username"{
  
}
variable "VM_Password"{
  
}
variable "Databricks_Enable"{
  
}
variable "DatabricksName"{
  
}
variable "purview_Enable"{
  
}
variable "purview_Name"{
  
}
/*
variable "notebook_subdirectory" {
  description = "A name for the subdirectory to store the notebook."
  type        = string
  default     = "Terraform"
}

variable "notebook_filename" {
  description = "The notebook's filename."
  type        = string
}

variable "notebook_language" {
  description = "The language of the notebook."
  type        = string
}

variable "cluster_name" {
  description = "A name for the cluster."
  type        = string
  default     = "My Cluster"
}

variable "cluster_autotermination_minutes" {
  description = "How many minutes before automatically terminating due to inactivity."
  type        = number
  default     = 60
}

variable "cluster_num_workers" {
  description = "The number of workers."
  type        = number
  default     = 1
}
*/
variable "job_name" {
  description = "A name for the job."
  type        = string
  default     = "My Job"
}

variable "DataShare_Name" { 
}
variable "DataShare_Enable" {
}