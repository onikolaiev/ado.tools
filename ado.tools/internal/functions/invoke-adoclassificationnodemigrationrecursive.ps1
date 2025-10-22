
<#
    .SYNOPSIS
        Migrates classification nodes (Areas or Iterations) recursively from source to target Azure DevOps organization.
        
    .DESCRIPTION
        This function handles the migration of classification nodes by checking for existing nodes in the target
        organization and updating them if necessary. It preserves the hierarchy and attributes of the nodes.
        
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
    .PARAMETER SourceToken
        Personal Access Token for the source Azure DevOps organization with work item tracking permissions.
    .PARAMETER TargetToken
        Personal Access Token for the target Azure DevOps organization with work item tracking permissions.
    .PARAMETER TargetProjectName
        The name of the target Azure DevOps project.
    .PARAMETER SourceNode
        The source classification node to migrate.
    .PARAMETER TargetParentNodes
        The collection of target parent nodes to check for existing nodes.
    .PARAMETER StructureGroup
        The classification node type: 'Areas' or 'Iterations'.
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use.
    .PARAMETER ParentPath
        The path of the parent node for building the full path.
        
    .EXAMPLE
        Invoke-ADOClassificationNodeMigrationRecursive -SourceOrganization "sourceorg" -TargetOrganization "targetorg" -SourceToken $sourcePat -TargetToken $targetPat -TargetProjectName "TargetProject" -SourceNode $sourceNode -TargetParentNodes $targetParentNodes -StructureGroup 'Areas' -ApiVersion '7.2-preview.2'
        
        Migrates the specified source classification node and its children recursively to the target project.
        
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Invoke-ADOClassificationNodeMigrationRecursive {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][string]$TargetProjectName,
        [Parameter(Mandatory)][pscustomobject]$SourceNode,
        [Parameter()][array]$TargetParentNodes,
        [Parameter(Mandatory)][string]$StructureGroup,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter()][string]$ParentPath = ''
    )

    $migratedCount = 0
    $skippedCount = 0
    $errorCount = 0

    try {
        # Check if node already exists in target
        $existingNode = $null
        if ($TargetParentNodes) {
            $existingNode = $TargetParentNodes | Where-Object { $_.name -eq $SourceNode.name } | Select-Object -First 1
        }

        $currentPath = if ($ParentPath) { "$ParentPath/$($SourceNode.name)" } else { $SourceNode.name }

        if ($existingNode) {
            Write-PSFMessage -Level Verbose -Message "$StructureGroup node '$($SourceNode.name)' already exists at path '$currentPath'. Checking for updates..."
            
            # Check if we need to update attributes (for iterations with dates)
            $needsUpdate = $false
            if ($SourceNode.attributes -and $SourceNode.attributes.PSObject.Properties.Count -gt 0) {
                if (-not $existingNode.attributes) {
                    $needsUpdate = $true
                } else {
                    # Compare key attributes
                    foreach ($prop in $SourceNode.attributes.PSObject.Properties) {
                        if (-not $existingNode.attributes.PSObject.Properties[$prop.Name] -or 
                            $existingNode.attributes.($prop.Name) -ne $prop.Value) {
                            $needsUpdate = $true
                            break
                        }
                    }
                }
            }

            if ($needsUpdate) {
                Write-PSFMessage -Level Host -Message "Updating $StructureGroup node '$($SourceNode.name)' with new attributes..."
                
                $updateParams = @{
                    Organization = $TargetOrganization
                    Token = $TargetToken
                    Project = $TargetProjectName
                    StructureGroup = $StructureGroup
                    Path = $currentPath
                    Name = $SourceNode.name
                    ApiVersion = $ApiVersion
                }
                
                # Add attributes if present (typically for iterations with start/finish dates)
                if ($SourceNode.attributes) {
                    if ($SourceNode.attributes.startDate) {
                        $updateParams.StartDate = $SourceNode.attributes.startDate
                    }
                    if ($SourceNode.attributes.finishDate) {
                        $updateParams.FinishDate = $SourceNode.attributes.finishDate
                    }
                    if ($SourceNode.attributes -and $SourceNode.attributes.PSObject.Properties.Count -gt 0) {
                        # Convert PSCustomObject to Hashtable
                        $attributesHashtable = @{}
                        foreach ($property in $SourceNode.attributes.PSObject.Properties) {
                            $attributesHashtable[$property.Name] = $property.Value
                        }
                        $updateParams.Attributes = $attributesHashtable
                    }
                }
                
                $updated = Update-ADOClassificationNode @updateParams
                if ($updated) {
                    $migratedCount++
                    Write-PSFMessage -Level Verbose -Message "Successfully updated $StructureGroup node '$($SourceNode.name)'"
                } else {
                    $errorCount++
                }
            } else {
                Write-PSFMessage -Level Verbose -Message "$StructureGroup node '$($SourceNode.name)' is up to date. Skipping..."
                $skippedCount++
            }
            
            # Use existing node for children migration
            $targetNode = $existingNode
        } else {
            Write-PSFMessage -Level Host -Message "Creating $StructureGroup node '$($SourceNode.name)' at path '$currentPath'..."
            
            $addParams = @{
                Organization = $TargetOrganization
                Token = $TargetToken
                Project = $TargetProjectName
                StructureGroup = $StructureGroup
                Name = $SourceNode.name
                ApiVersion = $ApiVersion
            }
            
            # Set path for parent if not empty
            if ($ParentPath) {
                $addParams.Path = $ParentPath
            }
            
            # Add attributes if present (typically for iterations with start/finish dates)
            if ($SourceNode.attributes) {
                if ($SourceNode.attributes.startDate) {
                    $addParams.StartDate = $SourceNode.attributes.startDate
                }
                if ($SourceNode.attributes.finishDate) {
                    $addParams.FinishDate = $SourceNode.attributes.finishDate
                }
                if ($SourceNode.attributes -and $SourceNode.attributes.PSObject.Properties.Count -gt 0) {
                    # Convert PSCustomObject to Hashtable
                    $attributesHashtable = @{}
                    foreach ($property in $SourceNode.attributes.PSObject.Properties) {
                        $attributesHashtable[$property.Name] = $property.Value
                    }
                    $addParams.Attributes = $attributesHashtable
                }
            }
            
            $targetNode = Add-ADOClassificationNode @addParams
            
            if ($targetNode) {
                $migratedCount++
                Write-PSFMessage -Level Verbose -Message "Successfully created $StructureGroup node '$($SourceNode.name)'"
            } else {
                $errorCount++
                Write-PSFMessage -Level Error -Message "Failed to create $StructureGroup node '$($SourceNode.name)'"
                return @{ Migrated = $migratedCount; Skipped = $skippedCount; Errors = $errorCount }
            }
        }

        # Migrate children recursively
        if ($SourceNode.children -and $SourceNode.children.Count -gt 0) {
            Write-PSFMessage -Level Verbose -Message "Migrating $($SourceNode.children.Count) child nodes for '$($SourceNode.name)'..."
            
            foreach ($childNode in $SourceNode.children) {
                $childResult = Invoke-ADOClassificationNodeMigrationRecursive -SourceOrganization $SourceOrganization -TargetOrganization $TargetOrganization -SourceToken $SourceToken -TargetToken $TargetToken -TargetProjectName $TargetProjectName -SourceNode $childNode -TargetParentNodes $targetNode.children -StructureGroup $StructureGroup -ApiVersion $ApiVersion -ParentPath $currentPath
                $migratedCount += $childResult.Migrated
                $skippedCount += $childResult.Skipped
                $errorCount += $childResult.Errors
            }
        }

    } catch {
        Write-PSFMessage -Level Error -Message "Failed to migrate $StructureGroup node '$($SourceNode.name)': $($_.Exception.Message)"
        $errorCount++
    }

    return @{
        Migrated = $migratedCount
        Skipped = $skippedCount
        Errors = $errorCount
    }
}