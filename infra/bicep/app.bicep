targetScope = 'resourceGroup'

// =============================================================================
// 入力値
// =============================================================================

@description('Azureリソースを作成するリージョン')
param location string = resourceGroup().location

@description('既存のAzure Container Registry名')
param acrName string

@description('既存のApp Configuration名')
param appConfigName string

@description('既存のContainer Apps EnvironmentのリソースID')
param containerAppsEnvironmentId string

@description('ACAへ割り当てるUser Assigned Managed IdentityのリソースID')
param runtimeIdentityId string

@description('ACA上のアプリがDefaultAzureCredentialで使うClient ID')
param runtimeIdentityClientId string

@description('GitHub Actions用UAMIのprincipal ID')
param deployIdentityPrincipalId string

@description('App Configurationから取得するキー')
param imageTagKey string = 'app:imageTag'

@description('App Configurationから取得するラベル')
param appConfigLabel string = 'dev'

@description('作成するContainer App名')
param containerAppName string = 'ca-appconfig-poc'

var commonTags = {
  ManagedBy: 'IaC'
}

var containerAppsContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '358470bc-b998-42bd-ab17-a7e34c199c0f')

// =============================================================================
// CD側が管理するApp Configurationの値を読み取る
// =============================================================================

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: acrName
}

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-06-01' existing = {
  name: appConfigName
}

// existingなので、このBicepはKVを作成・更新しません。
// 「キー$ラベル」がARM上のリソース名になります。
resource imageTag 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' existing = {
  parent: appConfig
  // `$`の直後に`{`を置くとBicepの文字列補間として解釈されるため、別の引数に分けます。
  name: format('{0}{1}{2}', imageTagKey, '$', appConfigLabel)
}

var image = '${acr.properties.loginServer}/aca-app:${imageTag.properties.value}'

// =============================================================================
// App Configurationの現在値を使ってACAを作成・更新する
// =============================================================================

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: commonTags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${runtimeIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironmentId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      maxInactiveRevisions: 100
      ingress: {
        external: true
        allowInsecure: false
        clientCertificateMode: 'Ignore'
        targetPort: 8080
        transport: 'Auto'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: runtimeIdentityId
        }
      ]
    }
    template: {
      terminationGracePeriodSeconds: 0
      containers: [
        {
          name: containerAppName
          image: image
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: runtimeIdentityClientId
            }
            {
              name: 'AZURE_APPCONFIG_ENDPOINT'
              value: appConfig.properties.endpoint
            }
          ]
          probes: [
            {
              type: 'Liveness'
              tcpSocket: {
                port: 8080
              }
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              tcpSocket: {
                port: 8080
              }
              periodSeconds: 5
              timeoutSeconds: 5
              failureThreshold: 48
              successThreshold: 1
            }
            {
              type: 'Startup'
              tcpSocket: {
                port: 8080
              }
              initialDelaySeconds: 1
              periodSeconds: 1
              timeoutSeconds: 3
              failureThreshold: 240
            }
          ]
        }
      ]
      scale: {
        cooldownPeriod: 300
        minReplicas: 0
        maxReplicas: 10
        pollingInterval: 30
      }
    }
  }
}

// GitHub Actionsは、このContainer Appだけを更新できます。
resource deployContainerAppsContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerApp.id, deployIdentityPrincipalId, containerAppsContributorRoleId)
  scope: containerApp
  properties: {
    principalId: deployIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: containerAppsContributorRoleId
  }
}

output image string = image
output fqdn string = containerApp.properties.configuration.ingress.fqdn
