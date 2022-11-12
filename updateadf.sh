#!/bin/bash

if [[ ! -n $1 ]];
then 
    echo "You must pass in the path/name of the config file to process!"
    exit 1
fi

configFile=$1

#Enable dynamic install of cli extensions.
az config set extension.use_dynamic_install=yes_without_prompt

#Get the resource group and data factory name.
resourceGroup=$(jq -r '.resourceGroup' $configFile)
dataFactory=$(jq -r '.dataFactory' $configFile)

#Delete the existing pipelines.
pipelines=$(az datafactory pipeline list --factory-name $dataFactory --resource-group $resourceGroup -o tsv --query [].name)
pipelines=($pipelines)
for ((i = 0; i < ${#pipelines[*]}; i++))
do
    name=${pipelines[$i]}
    az datafactory pipeline delete --factory-name $dataFactory --name $name --resource-group $resourceGroup --yes    
done

#Delete the existing datasets.
datasets=$(az datafactory dataset list --factory-name $dataFactory --resource-group $resourceGroup -o tsv --query [].name)
datasets=($datasets)
for ((i = 0; i < ${#datasets[*]}; i++))
do
    name=${datasets[$i]}
    az datafactory dataset delete --factory-name $dataFactory --name $name --resource-group $resourceGroup --yes    
done

#Delete the existing linked services.
linkedServices=$(az datafactory linked-service list --factory-name $dataFactory --resource-group $resourceGroup -o tsv --query [].name)
linkedServices=($linkedServices)
for ((i = 0; i < ${#linkedServices[*]}; i++))
do
    name=${linkedServices[$i]}
    az datafactory linked-service delete --factory-name $dataFactory --name $name --resource-group $resourceGroup --yes
done

#Run through the linked services a second time.  We may get an error the first
#time trying to delete the key vault if the other linked services haven't been deleted yet.
linkedServices=$(az datafactory linked-service list --factory-name $dataFactory --resource-group $resourceGroup -o tsv --query [].name)
linkedServices=($linkedServices)
for ((i = 0; i < ${#linkedServices[*]}; i++))
do
    name=${linkedServices[$i]}
    az datafactory linked-service delete --factory-name $dataFactory --name $name --resource-group $resourceGroup --yes
done

#Get the global parameters for the data factory.
globalParameters=$(jq -r '.globalParameters' $configFile)

#Update the datafactory with the global parameters.
az datafactory create --name $dataFactory --resource-group $resourceGroup --global-parameters "$globalParameters"

#All of our connections are handled using keyvault or managed identities so the linked services don't need to change.
#However, the KeyVault itself has a URL that is stored in the json file.  We need to replace the dev keyvault with
#the appropriate environment.
keyvault=$(jq -r '.keyvault' $configFile)

#All of the json for the linked services, data sets, pipelines, etc store the data with a name and the detail json called
#properties.  We will have to separate those apart for the cli commands to work.

#Process the linked services.
let "linkedServiceCount=$(jq '.linkedServices | length' $configFile)"
for ((i = 0; i < $linkedServiceCount; i++))
do
    file=$(jq -r '.linkedServices['$i']' $configFile)

    name=$(jq -r '.name' $file)
    properties=$(jq '.properties' $file)

    #This additional jq checks to see if the type is an AzureKeyVault and replaces the url.  You could probably do something
    #more elegant in the config file setup.
    properties=$(echo $properties | jq --arg KEYVAULT "$keyvault" '. |= if .type == "AzureKeyVault" then .typeProperties.baseUrl = $KEYVAULT else . end') 

    az datafactory linked-service create --factory-name $dataFactory --resource-group $resourceGroup --linked-service-name $name --properties "$properties"
done

#Process the datasets.
let "datasetCount=$(jq '.datasets | length' $configFile)"
for ((i = 0; i < $datasetCount; i++))
do
    file=$(jq -r '.datasets['$i']' $configFile)
    
    name=$(jq -r '.name' $file)
    properties=$(jq '.properties' $file)
    
    az datafactory dataset create --factory-name $dataFactory --resource-group $resourceGroup --dataset-name $name --properties "$properties"
done

#Process the pipelines
let "pipelineCount=$(jq '.pipelines | length' $configFile)"
for ((i = 0; i < $pipelineCount; i++))
do
    file=$(jq -r '.pipelines['$i']' $configFile)
    
    name=$(jq -r '.name' $file)
    properties=$(jq '.properties' $file)

    az datafactory pipeline create --factory-name $dataFactory --resource-group $resourceGroup --name $name --pipeline "$properties"

done