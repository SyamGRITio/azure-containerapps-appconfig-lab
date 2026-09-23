locals {
  resource_group_name = "rg-aca-appconfig-poc"
  location            = "japaneast"
  appconfig_label     = "dev"

  common_tags = {
    ManagedBy = "IaC"
  }
  resource_name_suffix   = "20260921"
  github_repository_name = "azure-containerapps-appconfig-lab"
}
