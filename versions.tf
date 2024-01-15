# This file defines the terraform version, our azurerm provider version 
# It also define state backend in the storage account to be accessible by all other developers 
# and also to have separate state for each environment
terraform {
#    required_version = "1.2.2"
    required_providers {
        azurerm = {
            source  = "registry.terraform.io/hashicorp/azurerm"
            version = "~>3.11"
        }
    databricks = {
        source = "databricks/databricks"
        version = "1.29.0"
    }
    }
    backend "azurerm" {
        resource_group_name = "MetaData_Driven_Framework_Terraform_Backend_VNET"
        storage_account_name = "cgadlsdevterraform"
        container_name = "statefiles"
        key = "dev.terraform.tfstate"
        sas_token = "?sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupyx&se=2025-01-10T09:47:10Z&st=2024-01-07T01:47:10Z&spr=https,http&sig=SKXC2Xg84yaBNJGiCG0f0a7q8LVlMny%2BJxbQwTU2v30%3D"
    }
}
provider "azurerm" {
  tenant_id       = "4cda32ca-6b19-4051-8b93-85889e7947dd" #"b1ac35c5-fd11-43ba-a811-f82cc883731f"
  subscription_id = "2caa4674-ce46-47c8-b863-b222c129e397" #"134b824c-eec7-4134-b15d-9b182fe58f20"
  client_id       = "f2df94b0-08a8-4884-9583-9d50bb365f4b" #"465186df-2d55-4505-8fcc-6336690c6414"
  client_secret   = "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk" #"xXY8Q~EpFlzIhXL6Hj9TtHuHYgyD6k~ufJIAUdBo"
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
# provider "databricks" {
#   #host = "https://accounts.cloud.databricks.com" #var.databricks_connection_profile
#   azure_workspace_resource_id = var.Databricks_Enable == true && var.VNET_Enable == true ? azurerm_databricks_workspace.workspace_vnet[0].id : null
#   azure_client_id             = "f2df94b0-08a8-4884-9583-9d50bb365f4b"
#   azure_client_secret         = "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk"
#   azure_tenant_id             = "4cda32ca-6b19-4051-8b93-85889e7947dd"
#   #azure_workspace_resource_id = azurerm_databricks_workspace.workspace.id
#   #azure_client_id = "465186df-2d55-4505-8fcc-6336690c6414"
#   #azure_client_secret = "xXY8Q~EpFlzIhXL6Hj9TtHuHYgyD6k~ufJIAUdBo"
#   #azure_tenant_id = "b1ac35c5-fd11-43ba-a811-f82cc883731f"
# }


provider "databricks" {
  alias                       = "first"
  #azure_workspace_resource_id = module.dbw-default-first.id
  azure_workspace_resource_id = var.Databricks_Enable == true && var.VNET_Enable == false ? azurerm_databricks_workspace.workspace[0].id : null
  azure_client_id             = "f2df94b0-08a8-4884-9583-9d50bb365f4b"
  azure_client_secret         = "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk"
  azure_tenant_id             = "4cda32ca-6b19-4051-8b93-85889e7947dd"
}

provider "databricks" {
  alias                       = "second"
  #azure_workspace_resource_id = module.dbw-default-second.id
  azure_workspace_resource_id = var.Databricks_Enable == true && var.VNET_Enable == true ? azurerm_databricks_workspace.workspace_vnet[0].id : null
  #azure_workspace_resource_id = azurerm_databricks_workspace.workspace_vnet[0].id
  #host = azurerm_databricks_workspace.workspace_vnet[0].workspace_url
  azure_client_id             = "f2df94b0-08a8-4884-9583-9d50bb365f4b"
  azure_client_secret         = "ebC8Q~dlGEXIyQLFG1222ht4WwIvrBSq7h-escfk"
  azure_tenant_id             = "4cda32ca-6b19-4051-8b93-85889e7947dd"
}

