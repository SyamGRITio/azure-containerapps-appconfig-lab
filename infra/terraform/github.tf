# GitHub Actionsで使うRepository VariablesをTerraformで管理
# 値はこの構成で作成したAzureリソースから参照
resource "github_actions_variable" "azure_tenant_id" {
  repository    = local.github_repository_name
  variable_name = "AZURE_TENANT_ID"
  value         = data.azurerm_client_config.current.tenant_id
}

resource "github_actions_variable" "azure_subscription_id" {
  repository    = local.github_repository_name
  variable_name = "AZURE_SUBSCRIPTION_ID"
  value         = data.azurerm_client_config.current.subscription_id
}

resource "github_actions_variable" "azure_resource_group" {
  repository    = local.github_repository_name
  variable_name = "AZURE_RESOURCE_GROUP"
  value         = azurerm_resource_group.main.name
}

resource "github_actions_variable" "acr_name" {
  repository    = local.github_repository_name
  variable_name = "ACR_NAME"
  value         = azurerm_container_registry.main.name
}

resource "github_actions_variable" "azure_client_id" {
  repository    = local.github_repository_name
  variable_name = "AZURE_CLIENT_ID"
  value         = azurerm_user_assigned_identity.github_app_deploy.client_id
}

resource "github_actions_variable" "appconfig_name" {
  repository    = local.github_repository_name
  variable_name = "APPCONFIG_NAME"
  value         = azurerm_app_configuration.main.name
}

resource "github_actions_variable" "container_app_name" {
  repository    = local.github_repository_name
  variable_name = "CONTAINER_APP_NAME"
  value         = azurerm_container_app.main.name
}
