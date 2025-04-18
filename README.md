# **ado.tools**

Azure DevOps tools

## Overview

`ado.tools` is a PowerShell module designed to simplify and enhance the management of Azure DevOps resources. It provides a collection of functions and utilities to streamline workflows, enforce best practices, and improve productivity when working with Azure DevOps.

---

## Getting Started

### Install the latest module
```powershell
Install-Module -Name ado.tools
```

### Install without administrator privileges
```powershell
Install-Module -Name ado.tools -Scope CurrentUser
```

### List all available commands/functions
```powershell
Get-Command -Module ado.tools
```

### Update the module
```powershell
Update-Module -Name ado.tools
```

### Update the module - force
```powershell
Update-Module -Name ado.tools -Force
```

---

## Available Functions

# **Invoke-ADOAzureOpenAI**

The `Invoke-ADOAzureOpenAI` function integrates with Azure OpenAI to analyze and review codebases. It indexes the codebase, searches for relevant files, and queries Azure OpenAI to generate insights, such as identifying bugs, code smells, and improvements.

---

## **Parameters**

### `-OpenAIEndpoint`
- **Description**: The Azure OpenAI endpoint URL.
- **Type**: `string`
- **Mandatory**: Yes

### `-OpenAIApiKey`
- **Description**: The API key for authenticating with Azure OpenAI.
- **Type**: `string`
- **Mandatory**: Yes

### `-CodebasePath`
- **Description**: The path to the codebase to be indexed and reviewed.
- **Type**: `string`
- **Mandatory**: Yes

### `-IndexPath`
- **Description**: The path where the indexed codebase will be stored as a JSON file.
- **Type**: `string`
- **Mandatory**: No
- **Default**: `c:\temp\codebase_index.json`

### `-UserQuery`
- **Description**: The query or instructions for Azure OpenAI to perform the code review.
- **Type**: `string`
- **Mandatory**: Yes

### `-Filenames`
- **Description**: A list of specific filenames to filter the search results.
- **Type**: `array`
- **Mandatory**: Yes

---

## **Examples**

### Example 1: Basic Usage
**Description**: Analyze a codebase for bugs and improvements using Azure OpenAI.
```powershell
# Define the required parameters
$openaiEndpoint = "https://YourAzureOpenApiEndpoint"
$openaiApiKey = "your-api-key"
$codebasePath = "C:\Projects\MyCodebase"
$userQuery = "Analyze the code for bugs and improvements."
$filesToAnalize = @("example1.al", "example2.al")

# Call the function
Invoke-ADOAzureOpenAI -OpenAIEndpoint $openaiEndpoint `
                      -OpenAIApiKey $openaiApiKey `
                      -CodebasePath $codebasePath `
                      -UserQuery $userQuery `
                      -Filenames $filesToAnalize
```
# **Invoke-ADOProjectMigration**

The `Invoke-ADOProjectMigration` function facilitates the migration of a project from one Azure DevOps organization to another/same. It retrieves the source project details, validates its existence, and prepares for migration to the target organization.

- Ensure that the source and target Azure DevOps organizations and tokens are valid and have the necessary permissions.
- The function handles the migration of:
  - Processes
  - Work item types
  - Fields
  - Behaviors
  - Picklists
  - States
  - Rules
  - Layouts
  - Work items
---

## **Parameters**

### `-SourceOrganization`
- **Description**: The name of the source Azure DevOps organization.
- **Type**: `string`
- **Mandatory**: Yes

### `-TargetOrganization`
- **Description**: The name of the target Azure DevOps organization.
- **Type**: `string`
- **Mandatory**: Yes

### `-SourceProjectName`
- **Description**: The name of the project in the source organization to be migrated.
- **Type**: `string`
- **Mandatory**: Yes

### `-TargetProjectName`
- **Description**: The name of the project in the target organization where the source project will be migrated.
- **Type**: `string`
- **Mandatory**: Yes

### `-SourceOrganizationToken`
- **Description**: The authentication token for accessing the source Azure DevOps organization.
- **Type**: `string`
- **Mandatory**: Yes

### `-TargetOrganizationToken`
- **Description**: The authentication token for accessing the target Azure DevOps organization.
- **Type**: `string`
- **Mandatory**: Yes

### `-ApiVersion`
- **Description**: The version of the Azure DevOps REST API to use.
- **Type**: `string`
- **Mandatory**: No
- **Default**: `7.1`

---

## **Examples**

### Example 1: Migrate a project between organizations
**Description**: Migrates the project `sourceProject` from the organization `sourceOrg` to the organization `targetOrg`.
```powershell
#Define the required parameters
$sourceOrg = "sourceOrg" 
$targetOrg = "targetOrg" 
$sourceProjectName = "sourceProject" 
$targetProjectName = "targetProject" 
$sourceOrgToken = "sourceOrgToken" 
$targetOrgToken = "targetOrgToken"

#Call the function
Invoke-ADOProjectMigration  -SourceOrganization $sourceOrg `
                            -TargetOrganization $targetOrg `
                            -SourceProjectName $sourceProjectName `
                            -TargetProjectName $targetProjectName `
                            -SourceOrganizationToken $sourceOrgToken ` 
                            -TargetOrganizationToken $targetOrgToken
```

---

## Requirements

- **PowerShell Version**: 5.1 or later

---

## License

This project is licensed under the MIT License. Feel free to use and modify it as needed.

---

## Author

Oleksandr Nikolaiev (@onikolaiev)