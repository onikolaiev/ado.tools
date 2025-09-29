
<#
    .SYNOPSIS
        Migrates work items from source project into target project using tracking field.
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
        
    .EXAMPLE
        $apiVersion = '7.1'
        $sourceOrg  = 'srcOrg'
        $targetOrg  = 'tgtOrg'
        $sourceToken = 'pat-src'
        $targetToken = 'pat-tgt'
        $sourceProjectName = 'Sample'
        $targetProjectName = 'MigratedProject'
        
        Invoke-ADOWorkItemDataMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken `
            -SourceProjectName $sourceProjectName -TargetProjectName $targetProjectName -ApiVersion $apiVersion
        # Migrates work items not yet copied (no tracking field value present in target).
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOWorkItemDataMigration {
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
    Write-PSFMessage -Level Verbose -Message "Loaded $($sourceItems.Count) source work items."

    # Prefetch target items ONCE to avoid O(n^2) calls; build map of already migrated Source IDs
    $targetMap = @{}
    $existingTargetItems = Get-ADOSourceWorkItemsList -SourceOrganization $TargetOrganization -SourceProjectName $TargetProjectName -SourceToken $TargetToken -Fields @('System.Id','System.Title','System.Description','System.WorkItemType','System.State','System.Parent','Custom.SourceWorkitemId') -ApiVersion $ApiVersion
    if ($existingTargetItems) {
        foreach ($t in $existingTargetItems) {
            $srcId = $t.'Custom.SourceWorkitemId'
            if ($srcId -and -not $targetMap.ContainsKey($srcId)) { $targetMap[$srcId] = $t.Url }
        }
    }
    $initialMapped = $targetMap.Count
    Write-PSFMessage -Level Verbose -Message "Found $initialMapped existing mapped work items in target (tracking field present)."

    $processed = 0
    foreach ($item in $sourceItems) {
        $processed++
        if ($targetMap.ContainsKey($item.'System.Id')) { continue }
        Invoke-ADOWorkItemsProcessing -SourceWorkItem $item -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -TargetOrganization $TargetOrganization -TargetProjectName $TargetProjectName -TargetToken $TargetToken -TargetWorkItemList ([ref]$targetMap) -ApiVersion $ApiVersion
    }
    $totalMapped = $targetMap.Count
    $createdThisRun = $totalMapped - $initialMapped
    Write-PSFMessage -Level Host -Message "Completed work item migration. Total mapped: $totalMapped (created this run: $createdThisRun, pre-existing: $initialMapped)."
}