locals {
  resource_group_name = "rg-aca-appconfig-poc"
  location            = "japaneast"
  appconfig_label     = "dev"

  common_tags = {
    ManagedBy = "Terraform"
  }
}

resource "time_static" "created" {}

locals {
  date_suffix = formatdate("YYYYMMDD", time_static.created.rfc3339)
}
