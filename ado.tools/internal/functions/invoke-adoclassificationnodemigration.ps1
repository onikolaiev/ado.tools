
<#
    .SYNOPSIS
        Migrates classification nodes (Areas and Iterations) from source to target Azure DevOps organization.
        
    .DESCRIPTION
        Migrates all Area and Iteration nodes from a source Azure DevOps project to a target project,
        preserving the hierarchy structure and attributes (like start/finish dates for iterations).
        The function handles both creating new nodes and updating existing ones.
        
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
        
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is '7.2-preview.2'.
        
    .PARAMETER IncludeAreas
        Switch to include Area nodes in migration. Default is true.
        
    .PARAMETER IncludeIterations
        Switch to include Iteration nodes in migration. Default is true.
        
    .EXAMPLE
        Invoke-ADOClassificationNodeMigration -SourceOrganization "sourceorg" -TargetOrganization "targetorg" -SourceToken $sourcePat -TargetToken $targetPat -SourceProjectName "SourceProject" -TargetProjectName "TargetProject"
        
        Migrates all Areas and Iterations from SourceProject to TargetProject.
        
    .EXAMPLE
        Invoke-ADOClassificationNodeMigration -SourceOrganization "sourceorg" -TargetOrganization "targetorg" -SourceToken $sourcePat -TargetToken $targetPat -SourceProjectName "SourceProject" -TargetProjectName "TargetProject" -IncludeAreas -IncludeIterations:$false
        
        Migrates only Area nodes, excluding Iterations.
        
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOClassificationNodeMigration {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][string]$SourceProjectName,
        [Parameter(Mandatory)][string]$TargetProjectName,
        [Parameter()][string]$ApiVersion = '7.2-preview.2',
        [Parameter()][switch]$IncludeAreas = $true,
        [Parameter()][switch]$IncludeIterations = $true
    )

    begin {
        Write-PSFMessage -Level Host -Message "Starting classification node migration from '$SourceProjectName' to '$TargetProjectName'..."
        $migratedCount = 0
        $skippedCount = 0
        $errorCount = 0
    }

    process {
        try {
            # Migrate Areas if requested
            if ($IncludeAreas) {
                Write-PSFMessage -Level Host -Message "Migrating Area nodes..."
                $result = Invoke-ADOClassificationNodeMigrationByType -SourceOrganization $SourceOrganization -TargetOrganization $TargetOrganization -SourceToken $SourceToken -TargetToken $TargetToken -SourceProjectName $SourceProjectName -TargetProjectName $TargetProjectName -StructureGroup 'Areas' -ApiVersion $ApiVersion
                $migratedCount += $result.Migrated
                $skippedCount += $result.Skipped
                $errorCount += $result.Errors
            }

            # Migrate Iterations if requested
            if ($IncludeIterations) {
                Write-PSFMessage -Level Host -Message "Migrating Iteration nodes..."
                $result = Invoke-ADOClassificationNodeMigrationByType -SourceOrganization $SourceOrganization -TargetOrganization $TargetOrganization -SourceToken $SourceToken -TargetToken $TargetToken -SourceProjectName $SourceProjectName -TargetProjectName $TargetProjectName -StructureGroup 'Iterations' -ApiVersion $ApiVersion
                $migratedCount += $result.Migrated
                $skippedCount += $result.Skipped
                $errorCount += $result.Errors
            }

        } catch {
            Write-PSFMessage -Level Error -Message "Classification node migration failed: $($_.Exception.Message)"
            $errorCount++
        }
    }

    end {
        Write-PSFMessage -Level Host -Message "Classification node migration completed. Migrated: $migratedCount, Skipped: $skippedCount, Errors: $errorCount"
        return @{
            Migrated = $migratedCount
            Skipped = $skippedCount
            Errors = $errorCount
        }
    }
}