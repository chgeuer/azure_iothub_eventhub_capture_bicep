# azure_iothub_eventhub_capture_bicep


## deploy

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchgeuer%2Fazure_iothub_eventhub_capture_bicep%2Fmain%2Fazuredeploy.json)

- During deployment, you need to specify a prefix string with which the template prefixes all resource names.

## summary

This sample demonstrates a few things

- An Azure IoT Hub receives messages from IoT devices
- The IoT Hub has two routes configured: 
  - The messages are routed into an Azure Storage account container in JSON format
  - The messages are routed into a subsequent Azure Event Hub
    - The messages arriving in Event Hub are captured using EventHub capture in an Azure Storage account in Avro format
    - Consumers can fetch from EventHub using the Kafka interface
- The three services (IoT Hub, Event Hub and Storage account) are deployed and wired together using an Azure Bicep file (which compiles down  wo a regular ARM template) 


## Architecture

![architecture](architecture.svg)

## demo setup

```bash
#!/bin/bash

resourceGroupName="b"

az group create \
  --name "${resourceGroupName}" \
  --location westeurope

az deployment group create \
  --resource-group "${resourceGroupName}" \
  --template-file ./azuredeploy.bicep
```

## submitting demo traffic

```bash
#!/bin/bash

deviceid="simulatedDevice"
prefix="chgp"
iotHubName="${prefix}iothub"
storageaccountname="${prefix}storage"

az iot hub device-identity create \
    --device-id "${deviceid}" \
    --hub-name "${iotHubName}"

az iot device send-d2c-message \
    --resource-group "${resourceGroupName}" \
    --hub-name "${iotHubName}" \
    --msg-count 200 \
    --device-id "${deviceid}"
```

## Listing the container contents

First, retrieve the connection string

```bash
#!/bin/bash

deviceid="simulatedDevice"
prefix="chgp"
iotHubName="${prefix}iothub"
storageaccountname="${prefix}storage"

connectionString="$(az storage account show-connection-string \
  --resource-group "${resourceGroupName}" \
  --name "${storageaccountname}" | \
  jq -r .connectionString)"
```

### list the JSON contents

```bash
#!/bin/bash

az storage blob list \
  --connection-string "${connectionString}" \
  --container-name 'json' | \
  jq -r ".[].name"
```

gives us 

```text
chgpiothub/00/2021/05/07/08/12.json
```


### list the Avro contents

```bash
#!/bin/bash

az storage blob list \
  --connection-string "${connectionString}" \
  --container-name 'capture' | \
  jq -r ".[].name"
```

```text
chgpeventhub/eventhub/0/2021/05/07/08/03/57.avro
chgpeventhub/eventhub/0/2021/05/07/08/08/57.avro
chgpeventhub/eventhub/0/2021/05/07/08/13/57.avro
chgpeventhub/eventhub/1/2021/05/07/08/03/57.avro
chgpeventhub/eventhub/1/2021/05/07/08/08/57.avro
chgpeventhub/eventhub/1/2021/05/07/08/13/57.avro
chgpeventhub/eventhub/2/2021/05/07/08/03/57.avro
chgpeventhub/eventhub/2/2021/05/07/08/08/57.avro
chgpeventhub/eventhub/2/2021/05/07/08/13/57.avro
chgpeventhub/eventhub/3/2021/05/07/08/03/57.avro
chgpeventhub/eventhub/3/2021/05/07/08/08/57.avro
chgpeventhub/eventhub/3/2021/05/07/08/13/57.avro
```
