#Variables
sqluser="sqladamin"
password='Password123!'
location="eastus"

rand=$((100 + $RANDOM % 1000))

az config set extension.use_dynamic_install=yes_without_prompt

#Create a resource group.
azureResourceGroup="devops$rand"
az group create --name $azureResourceGroup --location $location

#Create an adventureworks sql database
adventureworks="adventureworks$rand-sqlserver"
az sql db create --resource-group $azureResourceGroup --server $adventureworks --name adventureworks --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --auto-pause-delay 60 --sample-name AdventureWorksLT

watermark="watermark$rand-sqlserver"
az sql db create --resource-group $azureResourceGroup --server $watermark --name watermark --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --auto-pause-delay 60

datalake="datalake$"

#test   