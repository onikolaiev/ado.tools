
<#
    .SYNOPSIS
        Migrates states for each inherited WIT.
    .DESCRIPTION
        Migrates states assigned to each inherited WIT in process.
        This includes copying states from the source WITs to the target WITs, ensuring that all customizations are preserved.
        Additionally, it builds an automatic state mapping to facilitate the migration of work items by mapping source states to the most appropriate target states based on name and category.
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
    .PARAMETER SourceToken
        The authentication token for accessing the source Azure DevOps organization.
    .PARAMETER TargetToken
        The authentication token for accessing the target Azure DevOps organization.
    .PARAMETER SourceProcess
        The source process object containing details about the process to migrate.
    .PARAMETER TargetProcess
        The target process object containing details about the process to migrate to.
    .PARAMETER SourceWitList
        The list of source work item types to migrate.
    .PARAMETER TargetWitList
        The list of target work item types to migrate to.
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use.
    .EXAMPLE
        $apiVersion = '7.1'
        $sourceOrg  = 'srcOrg'
        $targetOrg  = 'tgtOrg'
        $sourceToken = 'pat-src'
        $targetToken = 'pat-tgt'
        $sourceProjectName = 'Sample'
        $sourceProjectMeta = (Get-ADOProjectList -Organization $sourceOrg -Token $sourceToken -ApiVersion $apiVersion -StateFilter All) | Where-Object name -eq $sourceProjectName
        $sourceProject = Get-ADOProject -Organization $sourceOrg -Token $sourceToken -ProjectId $sourceProjectMeta.id -IncludeCapabilities -ApiVersion $apiVersion
        $proc = Invoke-ADOProcessMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg -SourceToken $sourceToken -TargetToken $targetToken -SourceProject $sourceProject -ApiVersion $apiVersion
        $witResult = Invoke-ADOWorkItemTypeMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg -SourceToken $sourceToken -TargetToken $targetToken -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess -ApiVersion $apiVersion
        
        Invoke-ADOWorkItemStateMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess `
            -SourceWitList $witResult.SourceList -TargetWitList $witResult.TargetList -ApiVersion $apiVersion
        # Migrates custom states and builds auto state mapping.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
        
#>
function Invoke-ADOWorkItemStateMigration {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][pscustomobject]$SourceProcess,
        [Parameter(Mandatory)][pscustomobject]$TargetProcess,
        [Parameter(Mandatory)][System.Collections.IEnumerable]$SourceWitList,
        [Parameter(Mandatory)][System.Collections.IEnumerable]$TargetWitList,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    Convert-FSCPSTextToAscii -Text "Migrate states.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting to process states."
    if (-not $script:ADOStateAutoMap) { $script:ADOStateAutoMap = @{} }
    foreach ($wit in $SourceWitList) {
        Write-PSFMessage -Level Host -Message "Processing states for WIT '$($wit.name)'."
        $targetWit = $TargetWitList.Where({$_.name -eq $wit.name})
        if (-not $targetWit) { continue }
        $sourceStates = Get-ADOWorkItemTypeStateList -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName
        $targetStates = Get-ADOWorkItemTypeStateList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName
        foreach ($state in $sourceStates) {
            Write-PSFMessage -Level Host -Message "Checking state '$($state.name)'."
            $existing = $targetStates.Where({$_.name -eq $state.name})
            $sourceState = Get-ADOWorkItemTypeState -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName -StateId $state.id
            if (-not $existing) {
                Write-PSFMessage -Level Host -Message "State '$($state.name)' does not exist. Adding."
                
                # Calculate correct order based on existing states and categories
                $targetCategory = $sourceState.stateCategory
                
                # Find existing states in the same category
                $sameCategory = $targetStates | Where-Object { $_.stateCategory -eq $targetCategory }
                
                if ($sameCategory) {
                    # Add after the last state in the same category
                    $maxOrderInCategory = ($sameCategory | Measure-Object -Property order -Maximum).Maximum
                    $newOrder = $maxOrderInCategory + 1
                    Write-PSFMessage -Level Verbose -Message "Adding state to existing category '$targetCategory' with order $newOrder"
                } else {
                    # New category - try to find the right position by analyzing source order
                    $sourceStatesSorted = $sourceStates | Sort-Object order
                    $currentStateIndex = 0
                    for ($i = 0; $i -lt $sourceStatesSorted.Count; $i++) {
                        if ($sourceStatesSorted[$i].name -eq $sourceState.name) {
                            $currentStateIndex = $i
                            break
                        }
                    }
                    
                    # Look for existing target categories that come before this state in source
                    $insertAfterOrder = 0
                    for ($i = $currentStateIndex - 1; $i -ge 0; $i--) {
                        $prevSourceState = $sourceStatesSorted[$i]
                        $prevTargetStates = $targetStates | Where-Object { $_.stateCategory -eq $prevSourceState.stateCategory }
                        if ($prevTargetStates) {
                            $insertAfterOrder = ($prevTargetStates | Measure-Object -Property order -Maximum).Maximum
                            break
                        }
                    }
                    
                    # Look for existing target categories that come after this state in source  
                    $insertBeforeOrder = [int]::MaxValue
                    for ($i = $currentStateIndex + 1; $i -lt $sourceStatesSorted.Count; $i++) {
                        $nextSourceState = $sourceStatesSorted[$i]
                        $nextTargetStates = $targetStates | Where-Object { $_.stateCategory -eq $nextSourceState.stateCategory }
                        if ($nextTargetStates) {
                            $insertBeforeOrder = ($nextTargetStates | Measure-Object -Property order -Minimum).Minimum
                            break
                        }
                    }
                    
                    if ($insertBeforeOrder -eq [int]::MaxValue) {
                        # Add at the end
                        $newOrder = $insertAfterOrder + 1
                    } else {
                        # Insert between categories
                        $newOrder = $insertAfterOrder + 1
                        if ($newOrder -ge $insertBeforeOrder) {
                            Write-PSFMessage -Level Warning -Message "Cannot insert state '$($sourceState.name)' between existing categories. Adding at end."
                            $maxOrder = ($targetStates | Measure-Object -Property order -Maximum).Maximum
                            $newOrder = $maxOrder + 1
                        }
                    }
                    Write-PSFMessage -Level Verbose -Message "Adding state to new category '$targetCategory' with order $newOrder (between $insertAfterOrder and $insertBeforeOrder)"
                }
                
                $body = @{ 
                    name = $sourceState.name
                    color = $sourceState.color
                    stateCategory = $sourceState.stateCategory
                    order = $newOrder
                } | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Verbose -Message "Adding state '$($sourceState.name)' to target process '$($TargetProcess.name)' with calculated order $newOrder (category: $($sourceState.stateCategory)). Body: $body"
                $new = Add-ADOWorkItemTypeState -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -Body $body
                # Refresh target states list after adding new state
                if ($new) {
                    $targetStates = Get-ADOWorkItemTypeStateList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName
                }
            } else { $new = $existing }
            if ($sourceState.hidden -and $sourceState.customizationType -eq "system") {
                try {
                    $null = Hide-ADOWorkItemTypeState -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -StateId $new.id -Hidden 'true' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                } catch {
                    Write-PSFMessage -Level Warning -Message "Failed to hide state '$($sourceState.name)' (possibly already hidden)."
                }
            }
        }
        $targetStates = Get-ADOWorkItemTypeStateList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName
        $mapKeyPrefix = $wit.name + '|'
        $visibleTarget = $targetStates | Where-Object { -not $_.hidden }
        foreach ($s in $sourceStates) {
            $candidate = $null
            $exact = $visibleTarget | Where-Object { $_.name -eq $s.name }
            if ($exact) { $candidate = $exact | Select-Object -First 1 }
            else {
                if ($s.stateCategory) {
                    $catMatches = $visibleTarget | Where-Object { $_.stateCategory -eq $s.stateCategory }
                    if ($catMatches) { $candidate = ($catMatches | Sort-Object order | Select-Object -First 1) }
                }
                if (-not $candidate -and $visibleTarget) { $candidate = ($visibleTarget | Sort-Object order | Select-Object -First 1) }
            }
            if ($candidate) {
                $script:ADOStateAutoMap[$mapKeyPrefix + $s.name] = $candidate.name
            }
        }
        $stateMapDisplay = ($sourceStates | ForEach-Object { $_.name }) | ForEach-Object { $_ + '->' + ($script:ADOStateAutoMap[$mapKeyPrefix + $_]) }
        $stateMapJoined  = $stateMapDisplay -join '; '
        Write-PSFMessage -Level Verbose -Message ("State mapping for '{0}': {1}" -f $wit.name, $stateMapJoined)
    }
}