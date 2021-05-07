// https://gist.githubusercontent.com/chgeuer/a27fadef4df876380d5dd8fe84cf1edf/raw/6f94864983c5a8d5ef3c664bb4d7515a9f4f1219/capture.bicep

@minLength(3)
@maxLength(8)
param prefix string

var location = resourceGroup().location

var names = {
  prefix: prefix
  iothub: {
    routingEndpoint: {
      storage: 'storage'
      eventhub: 'eventhub'
    }
  }
  storageContainerName: {
    eventHubCapture: 'capture'
    iotHubJsonRouting: 'json'
  }
  partitionCount: {
    iotHub: 4
    eventHub: 4
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: '${names.prefix}storage'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource jsonFromIoTHubContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${storage.name}/default/${names.storageContainerName.iotHubJsonRouting}'
  properties: {
      publicAccess: 'None'
  }
}

resource captureContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${storage.name}/default/${names.storageContainerName.eventHubCapture}'
  properties: {
      publicAccess: 'None'
  }
}

resource eventhubNamespace 'Microsoft.EventHub/Namespaces@2017-04-01' = {
  name: '${names.prefix}eventhub'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    kafkaEnabled: true
  }
}

resource eventhub 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: '${eventhubNamespace.name}/eventhub'
  properties: {
    partitionCount: names.partitionCount.eventHub
    messageRetentionInDays: 7
    captureDescription: {
      enabled: true
      skipEmptyArchives: false
      encoding: 'Avro'
      intervalInSeconds: 300
      destination: {
        name: 'EventHubArchive.AzureBlockBlob'
        properties: {
          archiveNameFormat: '{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}'
          blobContainer: substring(captureContainer.name, lastIndexOf(captureContainer.name, '/') + 1)
          storageAccountResourceId: storage.id
        }
      }
    }
  }
}

resource iotHubAuthorizedToSendRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2017-04-01' = {
  name: '${eventhub.name}/iothubCanSend'
   properties: {
      rights: [
         'Send'
      ]
   }
}

resource iothub 'Microsoft.Devices/IotHubs@2020-08-01' = {
  name: '${names.prefix}iothub'
  location: location
  sku: {
    name: 'S1'
    capacity: 1
  }
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: names.partitionCount.iotHub
      }
    }
    routing: {
      endpoints: {
        storageContainers: [
          {
            name: names.iothub.routingEndpoint.storage
            fileNameFormat: '{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}.json'
            batchFrequencyInSeconds: 60
            encoding: 'JSON'
            connectionString: 'AccountName=${storage.name};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage};DefaultEndpointsProtocol=https'
            containerName: substring(jsonFromIoTHubContainer.name, lastIndexOf(jsonFromIoTHubContainer.name, '/') + 1)
          }
        ]
        eventHubs: [
          {
            name: names.iothub.routingEndpoint.eventhub
            connectionString: listKeys(iotHubAuthorizedToSendRule.id, iotHubAuthorizedToSendRule.apiVersion).primaryConnectionString
          }
        ]
      }
      routes: [
        {
          name: 'routeStorage'
          source: 'DeviceMessages'
          isEnabled: true
          condition: 'true'
          endpointNames: [
            names.iothub.routingEndpoint.storage
          ]
        }
        {
          name: 'routeEventhub'
          source: 'DeviceMessages'
          condition: 'true'
          endpointNames: [
            names.iothub.routingEndpoint.eventhub
          ]
          isEnabled: true
        }
      ]
      fallbackRoute: {
        isEnabled: true
        name: '$fallback'
        source: 'DeviceMessages'
        condition: 'true'
        endpointNames: [
          'events'
        ]
      }
    }
  }
}
