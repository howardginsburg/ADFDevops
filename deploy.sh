#Variables
sqluser="sqladamin"
password='Password123!'
location="eastus"

rand=$((100 + $RANDOM % 1000))

#Allow cli extensions to be installed automatically
az config set extension.use_dynamic_install=yes_without_prompt

#Create a resource group.
azureResourceGroup="devops$rand"
az group create --name $azureResourceGroup --location $location

#Create an adventureworks sql database and allow azure services to connect to it.
adventureworks="adventureworks$rand"
az sql server create -l $location -g $azureResourceGroup -n $adventureworks -u $sqluser -p $password
az sql server firewall-rule create -g $azureResourceGroup -s $adventureworks -n AllowAzure --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
az sql db create --resource-group $azureResourceGroup --server $adventureworks --name adventureworks --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --auto-pause-delay 60 --sample-name AdventureWorksLT

#Create a watermark sql database and allow azure services to connect to it.
watermark="watermark$rand"
az sql server create -l $location -g $azureResourceGroup -n $watermark -u $sqluser -p $password
az sql server firewall-rule create -g $azureResourceGroup -s $watermark -n AllowAzure --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
az sql db create --resource-group $azureResourceGroup --server $watermark --name watermark --edition GeneralPurpose --family Gen5 --capacity 2 --compute-model Serverless --auto-pause-delay 60

#Create the tables/procs/data necessary in the watermark database.
sqlcmd -S $watermark.database.windows.net -d watermark -U $sqluser -P $password  -i buildwatermark.sql

#Create an ADLS storage account.
datalake="datalake$rand"
az storage account create -n $datalake -g $azureResourceGroup --sku Standard_LRS --hns true
az storage container create --account-name $datalake -n lake

#Create a key vault.
keyvault="keyvault$rand"
az keyvault create --name $keyvault --resource-group $azureResourceGroup --public-network-access Enabled

#Create an azure data factory.
datafactory="datafactory$rand"
az datafactory create --name $datafactory --resource-group $azureResourceGroup

#Allow the ADF managed identity to access the key vault.
managedidentity=$(az datafactory show --name $datafactory --resource-group $azureResourceGroup -o tsv --query identity.principalId)
az keyvault set-policy -n $keyvault --secret-permissions get list --object-id $managedidentity

#Store the adventureworks connection string in key vault.
adventureworkssecret="Server=tcp:$adventureworks.database.windows.net,1433;Initial Catalog=adventureworks;Persist Security Info=False;User ID=$sqluser;Password=$password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
az keyvault secret set --name AdventureworksSQL --vault-name $keyvault --value "$adventureworkssecret"

#Store the watermark connection string in key vault.
watermarksecret="Server=tcp:$watermark.database.windows.net,1433;Initial Catalog=watermark;Persist Security Info=False;User ID=$sqluser;Password=$password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
az keyvault secret set --name WatermarkSQL --vault-name $keyvault --value "$watermarksecret"

#Store the data lake storage account key in key vault.
datalakesecret=$(az storage account keys list -g $azureResourceGroup -n $datalake --query "[0].value" -o tsv )
az keyvault secret set --name DataLake --vault-name $keyvault --value $datalakesecret