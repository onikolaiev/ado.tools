
<#
    .SYNOPSIS
        Migrates a project from a source Azure DevOps organization to a target Azure DevOps organization.
        
    .DESCRIPTION
        This function facilitates the migration of a project from one Azure DevOps organization to another.
        It retrieves the source project details, validates its existence, and prepares for migration to the target organization.
        
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
        
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
        
    .PARAMETER SourceProjectName
        The name of the project in the source organization to be migrated.
        
    .PARAMETER TargetProjectName
        The name of the project in the target organization where the source project will be migrated.
        
    .PARAMETER SourceOrganizationToken
        The authentication token for accessing the source Azure DevOps organization.
        
    .PARAMETER TargetOrganizationToken
        The authentication token for accessing the target Azure DevOps organization.
        
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".
        
    .EXAMPLE
        $sourceOrg = "sourceOrg"
        $targetOrg = "targetOrg"
        $sourceProjectName = "sourceProject"
        $targetProjectName = "targetProject"
        $sourceOrgToken = "sourceOrgToken"
        $targetOrgToken = "targetOrgToken"
        
        Invoke-ADOProjectMigration -SourceOrganization $sourceOrg `
            -TargetOrganization $targetOrg `
            -SourceProjectName $sourceProjectName `
            -TargetProjectName $targetProjectName `
            -SourceOrganizationToken $sourceOrgToken `
            -TargetOrganizationToken $targetOrgToken
        
        This example migrates the project "sourceProject" from the organization "sourceOrg" to the organization "targetOrg".
        
    .NOTES
        This function uses PSFramework for logging and exception handling.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Invoke-ADOProjectMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceOrganization,

        [Parameter(Mandatory = $true)]
        [string]$TargetOrganization,

        [Parameter(Mandatory = $true)]
        [string]$SourceProjectName,

        [Parameter(Mandatory = $true)]
        [string]$TargetProjectName,

        [Parameter(Mandatory = $true)]
        [string]$SourceOrganizationToken,

        [Parameter(Mandatory = $true)]
        [string]$TargetOrganizationToken,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $Script:ADOApiVersion
    )
    begin{
        Invoke-TimeSignal -Start
        $ErrorActionPreference = "Stop"
    }
    process{
        if (Test-PSFFunctionInterrupt) { return }

        # Log start of migration
        Write-PSFMessage -Level Host -Message "Starting migration from source organization '$sourceOrganization' to target organization '$targetOrganization'."
        Convert-FSCPSTextToAscii -Text "Start migration" -Font "Standard"
        ## GETTING THE SOURCE PROJECT INFORMATION 
        Write-PSFMessage -Level Host -Message "Fetching source project '$SourceProjectName' from organization '$sourceOrganization'."
        $sourceProjecttmp = (Get-ADOProjectList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $ApiVersion -StateFilter All).Where({$_.name -eq $SourceProjectName})
        if (-not $sourceProjecttmp) {
            Write-PSFMessage -Level Error -Message "Source project '$SourceProjectName' not found in organization '$sourceOrganization'. Exiting."
            return
        }
        Write-PSFMessage -Level Host -Message "Source project '$SourceProjectName' found. Fetching detailed information."
        $sourceProject = Get-ADOProject -Organization $sourceOrganization -Token $sourceOrganizationtoken -ProjectId "$($sourceProjecttmp.id)" -IncludeCapabilities -ApiVersion $ApiVersion
        $sourceProjectVersionControl = $sourceProject.capabilities.versioncontrol

        # PROCESS: ensure process exists in target
        $processResult = Invoke-ADOProjectMigration_Process -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProject $sourceProject -ApiVersion $ApiVersion
        $sourceProjectProcess = $processResult.SourceProcess
        $targetProjectProcess = $processResult.TargetProcess

        # Custom fields (global)
        Invoke-ADOProjectMigration_CustomFields -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -TargetProcessName $targetProjectProcess.name -ApiVersion $ApiVersion

        # Work item types
        $witResult = Invoke-ADOProjectMigration_WorkItemTypes -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -ApiVersion $ApiVersion
        $sourceWitList = $witResult.SourceList
        $targetWitList = $witResult.TargetList

        # Assign fields to WITs
        Invoke-ADOProjectMigration_WorkItemTypeFields -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -SourceWitList $sourceWitList -TargetWitList $targetWitList -ApiVersion $ApiVersion

        # Behaviors
        Invoke-ADOProjectMigration_Behaviors -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -ApiVersion $ApiVersion

        # Picklists
        Invoke-ADOProjectMigration_Picklists -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -TargetProcess $targetProjectProcess -ApiVersion $ApiVersion

        # States
        Invoke-ADOProjectMigration_States -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -SourceWitList $sourceWitList -TargetWitList $targetWitList -ApiVersion $ApiVersion

        # Rules
        Invoke-ADOProjectMigration_Rules -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -SourceWitList $sourceWitList -TargetWitList $targetWitList -ApiVersion $ApiVersion

        # Layouts
        Invoke-ADOProjectMigration_Layouts -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -SourceWitList $sourceWitList -TargetWitList $targetWitList -ApiVersion $ApiVersion

        # Project create/update
        Invoke-ADOProjectMigration_Project -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProject $sourceProject -TargetProcess $targetProjectProcess -TargetProjectName $TargetProjectName -SourceVersionControlCapabilities $sourceProjectVersionControl -ApiVersion $ApiVersion

        # Work items
        Invoke-ADOProjectMigration_WorkItems -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $sourceOrganizationtoken -TargetToken $targetOrganizationtoken -SourceProjectName $sourceProject.name -TargetProjectName $TargetProjectName -ApiVersion $ApiVersion

    }
    end{
        # Log the end of the operation
        Write-PSFMessage -Level Host -Message "Migration from source organization '$sourceOrganization' to target organization '$targetOrganization' completed successfully."
        Invoke-TimeSignal -End
    }
}