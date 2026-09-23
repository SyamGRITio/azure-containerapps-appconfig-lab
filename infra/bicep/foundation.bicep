targetScope = 'resourceGroup'

// =============================================================================
// 設定値
// =============================================================================

@description('Azureリソースを作成するリージョン')
param location string = resourceGroup().location

@description('Bicepを実行するユーザーのMicrosoft Entra object ID')
param deployerObjectId string

@description('GitHub ActionsへOIDCログインを許可するsubject')
param githubOidcSubject string = 'repo:SyamGRITio@195118654/azure-containerapps-appconfig-lab@1369020125:ref:refs/heads/main'

@description('Terraform版と同じAzure Container Registry名')
param acrName string = 'acrappcofigpoc20260921'

@description('Terraform版と同じApp Configuration名')
param appConfigName string = 'appcs-aca-appconfig-poc'

@description('Terraform版と同じKey Vault名')
param keyVaultName string = 'kv-appconfig-poc20260921'

@description('Terraform版と同じContainer Apps Environment名')
param environmentName string = 'cae-appconfig-poc'

@description('Terraform版と同じACA実行用UAMI名')
param runtimeIdentityName string = 'id-aca-runtime'

@description('Terraform版と同じGitHub Actions用UAMI名')
param deployIdentityName string = 'id-github-app-deploy'

var commonTags = {
  ManagedBy: 'IaC'
}

// Azure組み込みロールのIDです。
var acrRepositoryReaderRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b93aa761-3e63-49ed-ac28-beffa264f7ac'
)
var acrRepositoryWriterRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '2a1e307c-b015-4ebd-883e-5b7698a07328'
)
var acrRepositoryCatalogListerRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'bfdb9389-c9a5-478a-bb2f-ba9ca092c3c7'
)
var appConfigDataReaderRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '516239f1-63e1-4d78-a4de-a74fb236a071'
)
var appConfigDataOwnerRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'
)
var keyVaultSecretsUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)
var keyVaultSecretsOfficerRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
)

// =============================================================================
// 基盤リソース
// =============================================================================

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  tags: commonTags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
    }
    publicNetworkAccess: 'Enabled'
    roleAssignmentMode: 'AbacRepositoryPermissions'
    zoneRedundancy: 'Disabled'
  }
}

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-06-01' = {
  name: appConfigName
  location: location
  tags: commonTags
  sku: {
    name: 'Free'
  }
  properties: {
    dataPlaneProxy: {
      authenticationMode: 'Pass-through'
      privateLinkDelegation: 'Disabled'
    }
    disableLocalAuth: true
    enablePurgeProtection: false
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 7
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: commonTags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource runtimeIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: runtimeIdentityName
  location: location
  tags: commonTags
}

resource deployIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: deployIdentityName
  location: location
  tags: commonTags
}

// GitHubのmainブランチから発行されたOIDCトークンだけを、このUAMIで受け入れます。
resource githubFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: deployIdentity
  name: 'github-main'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: githubOidcSubject
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2026-01-01' = {
  name: environmentName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
        minimumCount: 0
        maximumCount: 0
      }
    ]
  }
}

// =============================================================================
// ACA実行用Identityの権限
// =============================================================================

resource runtimeAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, runtimeIdentity.id, acrRepositoryReaderRoleId)
  scope: acr
  properties: {
    principalId: runtimeIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrRepositoryReaderRoleId
  }
}

resource runtimeAppConfigReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appConfig.id, runtimeIdentity.id, appConfigDataReaderRoleId)
  scope: appConfig
  properties: {
    principalId: runtimeIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: appConfigDataReaderRoleId
  }
}

resource runtimeKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, runtimeIdentity.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: runtimeIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRoleId
  }
}

// =============================================================================
// GitHub Actions用Identityの権限
// =============================================================================

resource deployAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, deployIdentity.id, acrRepositoryWriterRoleId)
  scope: acr
  properties: {
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrRepositoryWriterRoleId
  }
}

resource deployAppConfigOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appConfig.id, deployIdentity.id, appConfigDataOwnerRoleId)
  scope: appConfig
  properties: {
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: appConfigDataOwnerRoleId
  }
}

// =============================================================================
// 検証を実行するユーザーの権限
// =============================================================================

resource deployerAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, deployerObjectId, acrRepositoryWriterRoleId)
  scope: acr
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: acrRepositoryWriterRoleId
  }
}

resource deployerAcrCatalogLister 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, deployerObjectId, acrRepositoryCatalogListerRoleId)
  scope: acr
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: acrRepositoryCatalogListerRoleId
  }
}

resource deployerAppConfigOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appConfig.id, deployerObjectId, appConfigDataOwnerRoleId)
  scope: appConfig
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: appConfigDataOwnerRoleId
  }
}

resource deployerKeyVaultOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, deployerObjectId, keyVaultSecretsOfficerRoleId)
  scope: keyVault
  properties: {
    principalId: deployerObjectId
    principalType: 'User'
    roleDefinitionId: keyVaultSecretsOfficerRoleId
  }
}

// =============================================================================
// 後続処理へ渡す値
// =============================================================================

output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output appConfigName string = appConfig.name
output appConfigEndpoint string = appConfig.properties.endpoint
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output runtimeIdentityId string = runtimeIdentity.id
output runtimeIdentityClientId string = runtimeIdentity.properties.clientId
output deployIdentityId string = deployIdentity.id
output deployIdentityClientId string = deployIdentity.properties.clientId
output deployIdentityPrincipalId string = deployIdentity.properties.principalId
