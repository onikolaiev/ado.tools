
<#
    .SYNOPSIS Migrates work items from source project into target project using tracking field.
    .DESCRIPTION
        This function migrates work items from a source Azure DevOps project to a target Azure DevOps project.
        It uses a tracking field to associate work items in the source project with their counterparts in the target project.

    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.

    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.

    .PARAMETER SourceToken
        The authentication token for accessing the source Azure DevOps organization.
        
    .PARAMETER TargetToken
        The authentication token for accessing the target Azure DevOps organization.

    .PARAMETER SourceProjectName
        The name of the source Azure DevOps project.

    .PARAMETER TargetProjectName
        The name of the target Azure DevOps project.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use.

    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOProjectMigration_WorkItems {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][string]$SourceProjectName,
        [Parameter(Mandatory)][string]$TargetProjectName,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    Convert-FSCPSTextToAscii -Text "Migrate work items.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting work item migration from '$SourceProjectName' to '$TargetProjectName'."
    $sourceItems = Get-ADOSourceWorkItemsList -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -ApiVersion $ApiVersion
    $targetMap = @{}
    foreach ($item in $sourceItems) {
        $existing = Get-ADOSourceWorkItemsList -SourceOrganization $TargetOrganization -SourceProjectName $TargetProjectName -SourceToken $TargetToken -Fields @('System.Id','System.Title','System.Description','System.WorkItemType','System.State','System.Parent','Custom.SourceWorkitemId') | Where-Object 'Custom.SourceWorkitemId' -EQ $item.'System.Id'
        if ($existing) { continue }
        Invoke-ADOWorkItemsProcessing -SourceWorkItem $item -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -TargetOrganization $TargetOrganization -TargetProjectName $TargetProjectName -TargetToken $TargetToken -TargetWorkItemList ([ref]$targetMap) -ApiVersion $ApiVersion
    }
    Write-PSFMessage -Level Host -Message "Completed work item migration. Migrated $($targetMap.Count) items."
}