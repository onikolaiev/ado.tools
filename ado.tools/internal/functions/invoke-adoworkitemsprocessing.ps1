
<#
    .SYNOPSIS
        Processes a source work item from Azure DevOps and creates or updates a corresponding work item in the target Azure DevOps project, maintaining parent-child relationships.
        
    .DESCRIPTION
        This function processes a source work item retrieved from Azure DevOps, builds the necessary JSON payload, and creates or updates a corresponding work item in the target Azure DevOps project. It also handles parent-child relationships by linking the work item to its parent if applicable. If the parent work item does not exist in the target project, it is created first.
        
    .PARAMETER SourceWorkItem
        The source work item object containing the fields to process.
        
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
        
    .PARAMETER SourceProjectName
        The name of the source Azure DevOps project.
        
    .PARAMETER SourceToken
        The personal access token (PAT) for the source Azure DevOps organization.
        
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
        
    .PARAMETER TargetProjectName
        The name of the target Azure DevOps project.
        
    .PARAMETER TargetToken
        The personal access token (PAT) for the target Azure DevOps organization.
        
    .PARAMETER TargetWorkItemList
        A hashtable containing mappings of source work item IDs to target work item URLs for parent-child relationships. Passed by reference.
        
    .PARAMETER ApiVersion
        (Optional) The API version to use. Default is `7.1`.
        
    .EXAMPLE
        # Example 1: Process a single work item and create it in the target project
        
        Invoke-ADOWorkItemsProcessing -SourceWorkItem $sourceWorkItem -SourceOrganization "source-org" `
            -SourceProjectName "source-project" -SourceToken "source-token" `
            -TargetOrganization "target-org" -TargetProjectName "target-project" `
            -TargetToken "target-token" -TargetWorkItemList ([ref]$targetWorkItemList)
        
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Invoke-ADOWorkItemsProcessing { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SourceWorkItem,

        [Parameter(Mandatory = $true)]
        [string]$SourceOrganization,

        [Parameter(Mandatory = $true)]
        [string]$SourceProjectName,

        [Parameter(Mandatory = $true)]
        [string]$SourceToken,

        [Parameter(Mandatory = $true)]
        [string]$TargetOrganization,

        [Parameter(Mandatory = $true)]
        [string]$TargetProjectName,

        [Parameter(Mandatory = $true)]
        [string]$TargetToken,

        [Parameter(Mandatory = $true)]
        [ref]$TargetWorkItemList,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        # Log the start of the operation
        Write-PSFMessage -Level Host -Message "Processing work item ID: $($SourceWorkItem.'System.Id'). Title: $($SourceWorkItem.'System.Title')."
        if (-not $script:ADOValidWorkItemStatesCache) {
            $script:ADOValidWorkItemStatesCache = @{}
        }
        if (-not $script:ADOWorkItemProcessingAttempts) {
            $script:ADOWorkItemProcessingAttempts = @{}
        }
    
    }

    process {
        $buildPatchBody = {
            param($stateValue)

            $ops = @(
                @{ op = 'add'; path = '/fields/System.Title';        value = "$($SourceWorkItem.'System.Title')" }
                @{ op = 'add'; path = '/fields/System.Description';  value = "$($SourceWorkItem.'System.Description')" }
                @{ op = 'add'; path = '/fields/Custom.SourceWorkitemId'; value = "$($SourceWorkItem.'System.Id')" }
            )
            if ($stateValue) {
                $ops += @{ op = 'add'; path = '/fields/System.State'; value = $stateValue }
            } else {
                Write-PSFMessage -Level Verbose -Message "Omitting explicit System.State to let server assign default."
            }

            # Remove empty Description to avoid some rule validation noise
            $ops = $ops | Where-Object {
                if ($_.path -eq '/fields/System.Description' -and ([string]::IsNullOrWhiteSpace($_.value))) {
                    $false
                } else { $true }
            }

            # Parent/Child relationship handling (ensure parent exists first)
            if ($SourceWorkItem.'System.Parent') {
                if (-not $TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']) {
                    Write-PSFMessage -Level Verbose -Message "Parent work item ID $($SourceWorkItem.'System.Parent') not found in target map. Creating parent first."
                    if (-not $script:ADOWorkItemProcessingAttempts.ContainsKey($SourceWorkItem.'System.Parent')) {
                        $allSourceItems = Get-ADOSourceWorkItemsList -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken
                        $parentItem = $allSourceItems | Where-Object { $_.'System.Id' -eq $SourceWorkItem.'System.Parent' }
                        if ($parentItem) {
                            $script:ADOWorkItemProcessingAttempts[$SourceWorkItem.'System.Parent'] = 1
                            Invoke-ADOWorkItemsProcessing -SourceWorkItem $parentItem `
                                -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken `
                                -TargetOrganization $TargetOrganization -TargetProjectName $TargetProjectName -TargetToken $TargetToken `
                                -TargetWorkItemList $TargetWorkItemList -ApiVersion $ApiVersion
                        }
                    } else {
                        Write-PSFMessage -Level Verbose -Message "Skipping recursive attempt to create parent ID $($SourceWorkItem.'System.Parent') again."                    
                    }
                }

                if ($TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']) {
                    $ops += @{
                        op   = 'add'
                        path = '/relations/-'
                        value = @{
                            rel        = 'System.LinkTypes.Hierarchy-Reverse'
                            url        = $TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']
                            attributes = @{ comment = 'Parent link' }
                        }
                    }
                }
            }

            $ops | ConvertTo-Json -Depth 10
        }

        # Phase 1: Always create WITHOUT explicit state. Let server assign default.
        $originalState = $SourceWorkItem.'System.State'
        $witType = $SourceWorkItem.'System.WorkItemType'
        $autoMappedState = $null
        if ($script:ADOStateAutoMap) {
            $mappingKey = $witType + '|' + $originalState
            if ($script:ADOStateAutoMap.ContainsKey($mappingKey)) {
                $autoMappedState = $script:ADOStateAutoMap[$mappingKey]
                if ($autoMappedState -and $autoMappedState -ne $originalState) {
                    Write-PSFMessage -Level Verbose -Message "Auto-mapped original state '$originalState' -> '$autoMappedState' for type '$witType'."
                }
            }
        }
        # Manual override support (administrator can define preferred initial state per WIT)
        #if ($script:ADOStateOverride -and $script:ADOStateOverride.ContainsKey($witType)) {
        #    Write-PSFMessage -Level Verbose -Message "Override state mapping for type '$witType' -> '$($script:ADOStateOverride[$witType])'."
        #    $autoMappedState = $script:ADOStateOverride[$witType]
        #}

        $creationBody = & $buildPatchBody $null
        Write-PSFMessage -Level Verbose -Message "Phase 1: Creating work item without explicit state for source ID $($SourceWorkItem.'System.Id')."
        $createdItem = $null
        try {
            $createdItem = Add-ADOWorkItem -Organization $TargetOrganization `
                                           -Token $TargetToken `
                                           -Project $TargetProjectName `
                                           -Type "`$$($SourceWorkItem.'System.WorkItemType')" `
                                           -Body $creationBody `
                                           -ApiVersion $ApiVersion `
                                           -ErrorAction Stop
        }
        catch {
            Write-PSFMessage -Level Error -Message "Initial creation (without state) failed for source ID $($SourceWorkItem.'System.Id'): $($_.Exception.Message)"
        }

        if ($createdItem -and $createdItem.url) {
            $TargetWorkItemList.Value[$SourceWorkItem.'System.Id'] = $createdItem.url
            Write-PSFMessage -Level Verbose -Message "Created target work item (initial) SourceID=$($SourceWorkItem.'System.Id') => $($createdItem.url)"

            # Phase 2: If we have an auto/override mapped state that differs from server-assigned and is valid -> patch
            $needPatch = $false
            $targetAssignedState = $createdItem.fields.'System.State'
            $desiredState = $autoMappedState
            if ($desiredState -and $desiredState -ne $targetAssignedState) { $needPatch = $true }

            if ($needPatch) {
                Write-PSFMessage -Level Verbose -Message "Phase 2: Patching state -> '$desiredState' (current='$targetAssignedState')."

                try {
                    $patchBody = @(
                        @{
                            op    = "add"
                            path  = "/fields/System.State"
                            value = "$autoMappedState"
                        }
                    ) | ConvertTo-Json -Depth 2
                    $null = Update-ADOWorkItem -Organization $TargetOrganization `
                                                    -Token $TargetToken `
                                                    -Project $TargetProjectName `
                                                    -Id $createdItem.id `
                                                    -Body [$patchBody] `
                                                    -ApiVersion $ApiVersion `
                                                    -ErrorAction Stop
                    Write-PSFMessage -Level Verbose -Message "Patched work item $($createdItem.id) state -> '$desiredState'."
                }
                catch {
                    Write-PSFMessage -Level Warning -Message "Failed to patch state to '$desiredState' for work item $($createdItem.id): $($_.Exception.Message)"
                }
            }
        }
        else {
            Write-PSFMessage -Level Error -Message "Failed to create target work item for source ID $($SourceWorkItem.'System.Id') in phase 1. No further patching."
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Host -Message "Completed processing of work item ID: $($SourceWorkItem.'System.Id')."
    }
}