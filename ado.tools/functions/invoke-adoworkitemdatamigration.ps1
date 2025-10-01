
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
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter()][bool]$MigrateAttachments = $true,
        [Parameter()][bool]$MigrateComments = $true,
        [Parameter()][bool]$RewriteInlineAttachmentLinks = $true,
        [Parameter()][bool]$DownloadInlineAttachments = $true
    )
    Convert-FSCPSTextToAscii -Text "Migrate work items.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting work item migration from '$SourceProjectName' to '$TargetProjectName'."

    if ($script:ADOStateAutoMap.Count -eq 0 -or -not $script:ADOStateAutoMap) {
        Write-PSFMessage -Level Verbose -Message "Initialized state auto-mapping dictionary."
        $sourceProjecttmp = (Get-ADOProjectList -Organization $sourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -StateFilter All).Where({$_.name -eq $SourceProjectName})
        if (-not $sourceProjecttmp) {
            Write-PSFMessage -Level Error -Message "Source project '$SourceProjectName' not found in organization '$sourceOrganization'. Exiting."
            return
        }
        $sourceProject = Get-ADOProject -Organization $sourceOrganization -Token $SourceToken -ProjectId "$($sourceProjecttmp.id)" -IncludeCapabilities -ApiVersion $ApiVersion
        $processResult = Invoke-ADOProcessMigration -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $SourceToken -TargetToken $TargetToken -SourceProject $sourceProject -ApiVersion $ApiVersion
        $sourceProjectProcess = $processResult.SourceProcess
        $targetProjectProcess = $processResult.TargetProcess
        $witResult = Invoke-ADOWorkItemTypeMigration -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $SourceToken -TargetToken $TargetToken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -ApiVersion $ApiVersion
        $sourceWitList = $witResult.SourceList
        $targetWitList = $witResult.TargetList
        Invoke-ADOWorkItemStateMigration -SourceOrganization $sourceOrganization -TargetOrganization $targetOrganization -SourceToken $SourceToken -TargetToken $TargetToken -SourceProcess $sourceProjectProcess -TargetProcess $targetProjectProcess -SourceWitList $sourceWitList -TargetWitList $targetWitList -ApiVersion $ApiVersion
    }



    $sourceItems = Get-ADOSourceWorkItemsList -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -ApiVersion $ApiVersion
    if ($sourceItems) {
        # Ensure deterministic order: ascending by numeric System.Id
        $sourceItems = $sourceItems | Sort-Object { [int]($_.'System.Id') }
    }
    Write-PSFMessage -Level Verbose -Message "Loaded $($sourceItems.Count) source work items (sorted ascending by System.Id)."

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
    $skippedExisting = 0
    foreach ($item in $sourceItems) {
        $processed++
        $sid = $item.'System.Id'
        #if ($targetMap.ContainsKey($sid)) { $skippedExisting++; continue }
        Invoke-ADOWorkItemsProcessing -SourceWorkItem $item -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -TargetOrganization $TargetOrganization -TargetProjectName $TargetProjectName -TargetToken $TargetToken -TargetWorkItemList ([ref]$targetMap) -ApiVersion $ApiVersion -MigrateAttachments:$MigrateAttachments -MigrateComments:$MigrateComments -RewriteInlineAttachmentLinks:$RewriteInlineAttachmentLinks -DownloadInlineAttachments:$DownloadInlineAttachments
    }
    $totalMapped = $targetMap.Count
    $createdThisRun = $totalMapped - $initialMapped
    Write-PSFMessage -Level Host -Message "Completed work item migration. Total mapped: $totalMapped (created this run: $createdThisRun, pre-existing: $initialMapped, skipped existing: $skippedExisting)."
}