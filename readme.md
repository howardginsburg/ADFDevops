# DevOps Patterns for Azure Data Factory

The Microsoft supported mechanism for CICD in Azure Data Factory is an ARM deployment + Parameters.  A downside to this is when a combination of projects are being performed within the same ADF environment and will go through the CICD lifecycle on different timelines.  For instances when behavior needs to be configurable, Microsoft recommends using feature flags in ADF and this sample shows that.  There is also an alternative way to deploy ADF environments, and that is through using Azure CLI (or Powershell), and iterating through the underlying json files that the ADF workspace creates and that is also a focus of this sample to create a cherry picking pattern.  It is important to note that an opensource project, [sqlplayer](https://github.com/SQLPlayer/azure.datafactory.tools), exists that may better at solving for this use case.  This sample illustrates a more scripting style of solving for the problem.

## Overview

This sample creates the following resources:

- Azure SQL Database with the Adventureworks database
- Azure Data Lake aka Azure Storage with the hierarchical file store enabled
- Azure Key Vault for credential storage
- Azure SQL Database with a script to create a watermark database
- Azure Data Factory

It then creates the necessary keys in Azure Key Vault and also creates a policy to allow the Azure Data Factory managed identity to access the secrets.

## Deployment

### Azure Resources

1. Import this repo into [Azure DevOps](https://learn.microsoft.com/azure/devops/repos/git/import-git-repository?view=azure-devops) or [GitHub](https://docs.github.com/get-started/importing-your-projects-to-github/importing-source-code-to-github/importing-a-repository-with-github-importer)
2. Open an Azure Cloudshell bash session.
3. Copy deploy.sh and buildwatermark.sql into session or clone the entire repo.
4. Run the deployment script.
    - `bash deploy.sh`

### Configure the Development instance of Azure Data Factory

The deployment script that runs creates the foundation of an environment to begin with.  Our dev environment needs to be connected to ADO or GitHub.

1. Open your Azure Data Factory workspace.
2. Select the 'Manage' toolbox on the left side.
3. Select 'Git Configuration'
4. Select 'Configure'
5. Configure the settings to connect to your ADO or GitHub repo.
6. Specify '/adf' as the root folder.

## Running the Pipelines

### AzureSQLToBronze

This pipeline demonstrates how to leverage parameters for establishing connections to different databases, using a json file to specify the tables and datalake folders to land the data into, a watermark mechanism for only grabbing changed records, and a dataset with will dynamically build out a folder structure based on the rundate passed in.

1. Select 'Trigger Now' on the pipeline.

    - Tables = contents of AdventureWorksToBronze.json
    - RunDate = a date in the format of yyyy-mm-dd

2. Monitor the progress of the job and see that three tables are queried and the folder structure and csv files are landed into the data lake.

### Feature

This pipeline illustrates how to use feature flags within pipelines by using conditional logic and global parameters.

1. View the pipeline and see how conditional logic is used to determine the query to execute.
2. Select 'Trigger Now' on the pipeline.

    - RunDate = a date in the format of yyyy-mm-dd

3. Montor the progress of the job and see how the csv file created.

### SamplePipeline

This pipeline serves no functional purpose, but is used to illustrate how we can cherry pick in the config files and stop something from moving from one environment to another.

## CICD

To illustrate how one might create a pipeline in ADO or GitHub, we can use a [script](/deploy.sh) and configuration that will drive what artifacts get deployed.  The script will parse the configuration file passed in, delete all the existing items from the data factory, and then deploy just the items that we want there.

### Simulate QA

For our test environment, we will deploy all of the ADF resources, but disable the feature flag.

1. Run `bash deploy.sh` to create a secondary instance of the environment.
2. Edit adf-config-test.json

    - Update the resource group.
    - Update the data factory name.
    - Update the key vault url.

3. Run `bash updateadf.sh adf-config-test.json`
4. Open the instance of Azure Data Factory and note that there are 3 pipelines, and the global parameter for FeatureA is true.

### Simulate Production

For our production environment, we will deploy all of the ADF resources, disable the feature flag, and prevent a Pipeline from being deployed.

1. Run `bash deploy.sh` to create a secondary instance of the environment.
2. Edit adf-config-prod.json

    - Update the resource group.
    - Update the data factory name.
    - Update the key vault url.
    - Note that FeatureFlagA is now false and that the pipeline and dataset entries for SamplePipeline have been removed from the file.

3. Run `bash updateadf.sh adf-config-prod.json`.
4. Open the instance of Azure Data Factory and note that there are 2 pipelines, and the global parameter for FeatureA is false.

## Next Steps

Translate the deploy.sh file into pipelines in ADO or GitHub to suit your needs.  Before you go down this road, consider sqlplayer!
