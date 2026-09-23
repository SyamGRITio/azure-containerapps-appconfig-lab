targetScope = 'resourceGroup'

// Terraform版で部分applyした初期設定と同じ内容を、一度だけ作成します。
// app:imageTagとSecret実値は、作成後にCDまたは手動操作で更新します。

@description('既存のApp Configuration名')
param appConfigName string = 'appcs-aca-appconfig-poc'

@description('既存のKey Vault名')
param keyVaultName string = 'kv-appconfig-poc20260921'

@description('App Configurationのラベル')
param appConfigLabel string = 'dev'

var commonTags = {
  ManagedBy: 'IaC'
}

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-06-01' existing = {
  name: appConfigName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource imageTag 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: format('{0}{1}{2}', 'app:imageTag', '$', appConfigLabel)
  properties: {
    value: 'value'
    tags: commonTags
  }
}

resource message 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: format('{0}{1}{2}', 'app:message', '$', appConfigLabel)
  properties: {
    value: 'Azure Container Apps & App Configuration Lab\r\nAzure Container Appsのイメージ更新をTerraformから分離するための検証をしています'
    tags: commonTags
  }
}

resource secretMessage 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = {
  parent: appConfig
  name: format('{0}{1}{2}', 'app:secretMessage', '$', appConfigLabel)
  properties: {
    value: '{"uri":"${keyVault.properties.vaultUri}secrets/app-secret-message"}'
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    tags: commonTags
  }
}

resource appSecretMessage 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'app-secret-message'
  properties: {
    value: 'bootstrap'
  }
}
