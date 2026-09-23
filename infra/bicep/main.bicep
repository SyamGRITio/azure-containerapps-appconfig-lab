targetScope = 'subscription'

@description('検証用Resource Group名')
param resourceGroupName string = 'rg-aca-appconfig-poc'

@description('Azureリソースを作成するリージョン')
param location string = 'japaneast'

@description('Bicepを実行するユーザーのMicrosoft Entra object ID')
param deployerObjectId string

@description('GitHub ActionsへOIDCログインを許可するsubject')
param githubOidcSubject string = 'repo:SyamGRITio@195118654/azure-containerapps-appconfig-lab@1369020125:ref:refs/heads/main'

var commonTags = {
  ManagedBy: 'IaC'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

module foundation './foundation.bicep' = {
  name: 'foundation'
  scope: resourceGroup
  params: {
    deployerObjectId: deployerObjectId
    githubOidcSubject: githubOidcSubject
    location: location
  }
}

output resourceGroupName string = resourceGroup.name
output acrName string = foundation.outputs.acrName
output appConfigName string = foundation.outputs.appConfigName
output keyVaultName string = foundation.outputs.keyVaultName
output containerAppsEnvironmentId string = foundation.outputs.containerAppsEnvironmentId
output runtimeIdentityId string = foundation.outputs.runtimeIdentityId
output runtimeIdentityClientId string = foundation.outputs.runtimeIdentityClientId
output deployIdentityPrincipalId string = foundation.outputs.deployIdentityPrincipalId
