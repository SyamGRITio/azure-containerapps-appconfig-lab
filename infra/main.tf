data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags
}

# ACR,APPCS,KV
## Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                                         = "acrappcofigpoc${local.date_suffix}"
  resource_group_name                          = azurerm_resource_group.main.name
  location                                     = local.location
  sku                                          = "Basic"
  azuread_authentication_as_arm_policy_enabled = true
  public_network_access_enabled                = true
  retention_policy_in_days                     = 0
  role_assignment_mode                         = "AbacRepositoryPermissions"
  zone_redundancy_enabled                      = false
  tags                                         = local.common_tags
}

## App Configuration
resource "azurerm_app_configuration" "main" {
  name                                 = "appcs-aca-appconfig-poc"
  resource_group_name                  = azurerm_resource_group.main.name
  location                             = local.location
  sku                                  = "free"
  data_plane_proxy_authentication_mode = "Pass-through"
  local_auth_enabled                   = false
  tags                                 = local.common_tags
}

### Keys
resource "azurerm_app_configuration_key" "secret_message" {
  configuration_store_id = azurerm_app_configuration.main.id
  content_type           = "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8"
  type                   = "vault"
  key                    = "app:secretMessage"
  label                  = local.appconfig_label
  tags                   = local.common_tags
  vault_key_reference    = "${azurerm_key_vault.main.vault_uri}secrets/app-secret-message"
}

resource "azurerm_app_configuration_key" "image_tag" {
  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "app:imageTag"
  value                  = "value"
  type                   = "kv"
  label                  = local.appconfig_label
  tags                   = local.common_tags
  lifecycle {
    ignore_changes = [value]
  }
}

resource "azurerm_app_configuration_key" "message" {
  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "app:message"
  value                  = "Azure Container Apps & App Configuration Lab\r\nAzure Container Appsのイメージ更新をTerraformから分離するための検証をしています"
  type                   = "kv"
  label                  = local.appconfig_label
  tags                   = local.common_tags
}

## keyvault
resource "azurerm_key_vault" "main" {
  name                          = "kv-appconfig-poc${local.date_suffix}"
  location                      = local.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  public_network_access_enabled = true
  rbac_authorization_enabled    = true
  sku_name                      = "standard"
  soft_delete_retention_days    = 90
  tags                          = local.common_tags

}

### Secret
resource "azurerm_key_vault_secret" "app_secret_message" {
  key_vault_id = azurerm_key_vault.main.id
  name         = "app-secret-message"
  value        = "bootstrap"
  lifecycle {
    ignore_changes = [value]
  }
}


# ユーザー割り当てマネージドID
resource "azurerm_user_assigned_identity" "github_app_deploy" {
  name                = "id-github-app-deploy"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  tags                = local.common_tags
}

resource "azurerm_user_assigned_identity" "aca_runtime" {
  name                = "id-aca-runtime"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "github_app_deploy" {
  for_each = local.github_app_deploy_roles

  principal_id         = azurerm_user_assigned_identity.github_app_deploy.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_name = each.value.role_definition_name
  scope                = each.value.scope
}

resource "azurerm_role_assignment" "aca_runtime" {
  for_each = local.aca_runtime_roles

  principal_id         = azurerm_user_assigned_identity.aca_runtime.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_name = each.value.role_definition_name
  scope                = each.value.scope
}

## OIDC設定
resource "azurerm_federated_identity_credential" "github_app_deploy" {
  user_assigned_identity_id = azurerm_user_assigned_identity.github_app_deploy.id
  name                      = "github-main"
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:SyamGRITio@195118654/azure-containerapps-appconfig-lab@1369020125:ref:refs/heads/main"
  audience = [
    "api://AzureADTokenExchange"
  ]
}


# Azure Container Apps
resource "azurerm_container_app_environment" "main" {
  name                  = "cae-appconfig-poc"
  resource_group_name   = azurerm_resource_group.main.name
  location              = local.location
  public_network_access = "Enabled"
  identity {
    type = "SystemAssigned"
  }
  workload_profile {
    maximum_count         = 0
    minimum_count         = 0
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  tags = local.common_tags
}

resource "azurerm_container_app" "main" {
  container_app_environment_id = azurerm_container_app_environment.main.id
  max_inactive_revisions       = 100
  name                         = "ca-appconfig-poc"
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.common_tags
  workload_profile_name        = "Consumption"
  identity {
    identity_ids = [azurerm_user_assigned_identity.aca_runtime.id, ]
    type         = "UserAssigned"
  }
  ingress {
    allow_insecure_connections = false
    client_certificate_mode    = "ignore"
    external_enabled           = true
    target_port                = 8080
    transport                  = "auto"
    traffic_weight {
      label           = null
      latest_revision = true
      percentage      = 100
      revision_suffix = null
    }
  }
  registry {
    identity = azurerm_user_assigned_identity.aca_runtime.id
    server   = azurerm_container_registry.main.login_server
  }
  template {
    cooldown_period_in_seconds       = 300
    max_replicas                     = 10
    min_replicas                     = 0
    polling_interval_in_seconds      = 30
    termination_grace_period_seconds = 0
    container {
      cpu    = 0.25
      image  = "${azurerm_container_registry.main.login_server}/aca-app:${azurerm_app_configuration_key.image_tag.value}"
      memory = "0.5Gi"
      name   = "ca-appconfig-poc"
      env {
        name        = "AZURE_CLIENT_ID"
        secret_name = null
        value       = azurerm_user_assigned_identity.aca_runtime.client_id
      }
      env {
        name        = "AZURE_APPCONFIG_ENDPOINT"
        secret_name = null
        value       = azurerm_app_configuration.main.endpoint
      }
      liveness_probe {
        failure_count_threshold = 3
        host                    = null
        initial_delay           = 0
        interval_seconds        = 10
        port                    = 8080
        timeout                 = 5
        transport               = "TCP"
      }
      readiness_probe {
        failure_count_threshold = 48
        host                    = null
        initial_delay           = 0
        interval_seconds        = 5
        port                    = 8080
        success_count_threshold = 1
        timeout                 = 5
        transport               = "TCP"
      }
      startup_probe {
        failure_count_threshold = 240
        host                    = null
        initial_delay           = 1
        interval_seconds        = 1
        port                    = 8080
        timeout                 = 3
        transport               = "TCP"
      }
    }

  }
  depends_on = [
    azurerm_role_assignment.aca_runtime
  ]
}

# 操作ユーザーに権限付与
resource "azurerm_role_assignment" "terraform_appconfig_data_owner" {
  scope                = azurerm_app_configuration.main.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "terraform_acr_writer" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "Container Registry Repository Writer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "terraform_acr_catalog_lister" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "Container Registry Repository Catalog Lister"
  principal_id         = data.azurerm_client_config.current.object_id
}
