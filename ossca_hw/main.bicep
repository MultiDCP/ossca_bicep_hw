@description('The name of the owner of the service')
@minLength(1)
param name string

param location string = resourceGroup().location
param loc string = 'krc'

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the service')
@minLength(1)
param publisherName string

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Isolated'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Consumption'

param skuCount int = 0

var rg = 'rg-${name}-${loc}'
var fncappname = 'fncapp-${name}-${loc}'

// 애저 저장소 어카운트
resource st 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: 'st${name}${loc}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// 애저 앱 서비스 플랜
resource csplan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'csplan-${name}-${loc}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: false //consumptionPlanIsLinux
  }
}

// 애저 펑션
resource fncapp 'Microsoft.Web/sites@2022-03-01' = {
  name: fncappname
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: csplan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${st.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(st.id, '2021-09-01').keys[0].value}'
        }
      ]
    }
    httpsOnly: true
  }
}

// 애저 로그 아날리틱스 워크스페이스
resource wrkspc 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'wrkspc-${name}-${loc}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// 애저 애플리케이션 인사이트
resource appins 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appins-${name}-${loc}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    IngestionMode: 'LogAnalytics'
    Request_Source: 'rest'
    WorkspaceResourceId: wrkspc.id
  }
}

// 애저 API 관리자
resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: 'apim-${name}-${loc}'
  location: location
  sku: {
    capacity: skuCount
    name: sku
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

output rn string = rg
