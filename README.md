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