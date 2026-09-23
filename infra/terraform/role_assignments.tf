locals {
  github_app_deploy_roles = {
    acr_writer = {
      role_definition_name = "Container Registry Repository Writer"
      scope                = azurerm_container_registry.main.id
    }

    appconfig_owner = {
      role_definition_name = "App Configuration Data Owner"
      scope                = azurerm_app_configuration.main.id
    }

    aca_contributor = {
      role_definition_name = "Container Apps Contributor"
      scope                = azurerm_container_app.main.id
    }
  }

  aca_runtime_roles = {
    acr_reader = {
      role_definition_name = "Container Registry Repository Reader"
      scope                = azurerm_container_registry.main.id
    }

    appconfig_reader = {
      role_definition_name = "App Configuration Data Reader"
      scope                = azurerm_app_configuration.main.id
    }

    kv_secrets_user = {
      role_definition_name = "Key Vault Secrets User"
      scope                = azurerm_key_vault.main.id
    }
  }
}

