
<#
    .SYNOPSIS
        Migrates classification nodes (Areas or Iterations) from source to target Azure DevOps organization by specified type.
        
    .DESCRIPTION
        Migrates either Area or Iteration nodes from a source Azure DevOps project to a target project,
        preserving the hierarchy structure and attributes (like start/finish dates for iterations).
        
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
    .PARAMETER SourceToken
        Personal Access Token for the source Azure DevOps organization with work item tracking permissions.
    .PARAMETER TargetToken
        Personal Access Token for the target Azure DevOps organization with work item tracking permissions.
    .PARAMETER SourceProjectName
        The name of the source Azure DevOps project.
    .PARAMETER TargetProjectName
        The name of the target Azure DevOps project.
    .PARAMETER StructureGroup
        The classification node type to migrate: 'Areas' or 'Iterations'.
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is '7.2-preview.2'.
    .EXAMPLE
        Invoke-ADOClassificationNodeMigrationByType -SourceOrganization "sourceorg" -TargetOrganization "targetorg" -SourceToken $sourcePat -TargetToken $targetPat -SourceProjectName "SourceProject" -TargetProjectName "TargetProject" -StructureGroup 'Areas' -ApiVersion '7.2-preview.2'
        
        Migrates all Area nodes from SourceProject to TargetProject.
        
    .EXAMPLE
        Invoke-ADOClassificationNodeMigrationByType -SourceOrganization "sourceorg" -TargetOrganization "targetorg" -SourceToken $sourcePat -TargetToken $targetPat -SourceProjectName "SourceProject" -TargetProjectName "TargetProject" -StructureGroup 'Areas' -ApiVersion '7.2-preview.2'
        
        Migrates all Area nodes from SourceProject to TargetProject.
        
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in
        the module for logging, error handling, and API interaction.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Invoke-ADOClassificationNodeMigrationByType {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][string]$SourceProjectName,
        [Parameter(Mandatory)][string]$TargetProjectName,
        [Parameter(Mandatory)][ValidateSet('Areas', 'Iterations')][string]$StructureGroup,
        [Parameter(Mandatory)][string]$ApiVersion
    )

    $migratedCount = 0
    $skippedCount = 0
    $errorCount = 0

    try {
        # Get source classification nodes (returns both Areas and Iterations)
        $sourceRoots = Get-ADOClassificationNodeRoot -Organization $SourceOrganization -Token $SourceToken -Project $SourceProjectName -ApiVersion $ApiVersion -Depth 99
        
        # Filter to get the specific structure group (Areas or Iterations)
        $structureTypeFilter = if ($StructureGroup -eq 'Areas') { 'area' } else { 'iteration' }
        $sourceRoot = $sourceRoots | Where-Object { $_.structureType -eq $structureTypeFilter } | Select-Object -First 1
        
        if (-not $sourceRoot -or -not $sourceRoot.children) {
            Write-PSFMessage -Level Verbose -Message "No $StructureGroup nodes found in source project."
            return @{ Migrated = 0; Skipped = 0; Errors = 0 }
        }

        # Get target classification nodes for comparison
        $targetRoots = Get-ADOClassificationNodeRoot -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -ApiVersion $ApiVersion -Depth 99
        $targetRoot = $targetRoots | Where-Object { $_.structureType -eq $structureTypeFilter } | Select-Object -First 1
        
        if (-not $targetRoot) {
            Write-PSFMessage -Level Warning -Message "No target $StructureGroup root found. This is unexpected."
            return @{ Migrated = 0; Skipped = 0; Errors = 1 }
        }

        # Migrate nodes recursively
        foreach ($sourceNode in $sourceRoot.children) {
            $result = Invoke-ADOClassificationNodeMigrationRecursive -SourceOrganization $SourceOrganization -TargetOrganization $TargetOrganization -SourceToken $SourceToken -TargetToken $TargetToken -TargetProjectName $TargetProjectName -SourceNode $sourceNode -TargetParentNodes $targetRoot.children -StructureGroup $StructureGroup -ApiVersion $ApiVersion
            $migratedCount += $result.Migrated
            $skippedCount += $result.Skipped
            $errorCount += $result.Errors
        }

    } catch {
        Write-PSFMessage -Level Error -Message "Failed to migrate $StructureGroup nodes: $($_.Exception.Message)"
        $errorCount++
    }

    return @{
        Migrated = $migratedCount
        Skipped = $skippedCount
        Errors = $errorCount
    }
}