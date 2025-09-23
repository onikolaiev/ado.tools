
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
    
    }

    process {
        $buildPatchBody = {
            param($stateValue)

            $ops = @(
                @{ op = 'add'; path = '/fields/System.Title';        value = "$($SourceWorkItem.'System.Title')" }
                @{ op = 'add'; path = '/fields/System.Description';  value = "$($SourceWorkItem.'System.Description')" }
                @{ op = 'add'; path = '/fields/Custom.SourceWorkitemId'; value = "$($SourceWorkItem.'System.Id')" }
                @{ op = 'add'; path = '/fields/System.State';        value = $stateValue }
            )

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
                    $allSourceItems = Get-ADOSourceWorkItemsList -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken
                    $parentItem = $allSourceItems | Where-Object { $_.'System.Id' -eq $SourceWorkItem.'System.Parent' }
                    if ($parentItem) {
                        Invoke-ADOWorkItemsProcessing -SourceWorkItem $parentItem `
                            -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken `
                            -TargetOrganization $TargetOrganization -TargetProjectName $TargetProjectName -TargetToken $TargetToken `
                            -TargetWorkItemList $TargetWorkItemList -ApiVersion $ApiVersion
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

        # Helper: retrieve valid states for a given type (cached)
        $getValidStates = {
            param($projectName, $witType)
            $cacheKey = ($projectName.ToLowerInvariant() + '|' + $witType)
            if ($script:ADOValidWorkItemStatesCache.ContainsKey($cacheKey)) {
                return $script:ADOValidWorkItemStatesCache[$cacheKey]
            }
            try {
                $escapedType = [uri]::EscapeDataString($witType)
                $uri = "/$projectName/_apis/wit/workitemtypes/$escapedType"
                $resp = Invoke-ADOApiRequest -Organization $TargetOrganization -Token $TargetToken -ApiUri $uri -Method GET -ApiVersion $ApiVersion -ErrorAction Stop
                $states = if ($resp.states) { $resp.states } elseif ($resp.value) { $resp.value } else { @() }
                $script:ADOValidWorkItemStatesCache[$cacheKey] = $states
                return $states
            }
            catch {
                Write-PSFMessage -Level Warning -Message "Unable to retrieve valid states for type '$witType': $($_.Exception.Message)"
                return @()
            }
        }

        # Prepare attempt queue: first the original state
        $originalState = $SourceWorkItem.'System.State'
        $attemptQueue  = New-Object System.Collections.Generic.List[string]
        $attemptQueue.Add($originalState)

        $created   = $false
        $lastError = $null

        while (-not $created -and $attemptQueue.Count -gt 0) {
            $candidateState = $attemptQueue[0]
            $attemptQueue.RemoveAt(0)

            try {
                $body = & $buildPatchBody $candidateState
                Write-PSFMessage -Level Verbose -Message "Creating work item (state='$candidateState') for source ID $($SourceWorkItem.'System.Id')."

                $targetWorkItem = Add-ADOWorkItem -Organization $TargetOrganization `
                                                -Token $TargetToken `
                                                -Project $TargetProjectName `
                                                -Type "`$$($SourceWorkItem.'System.WorkItemType')" `
                                                -Body $body `
                                                -ApiVersion $ApiVersion `
                                                -ErrorAction Stop

                if (-not $targetWorkItem.url) {
                    Write-PSFMessage -Level Error -Message "Creation returned empty URL for source ID $($SourceWorkItem.'System.Id')."
                } else {
                    $TargetWorkItemList.Value[$SourceWorkItem.'System.Id'] = $targetWorkItem.url
                }
                $created = $true
            }
            catch {
                $lastError = $_
                $msg = $_.Exception.Message

                # Detect unsupported state errors
                if ($msg -match 'not in the list of supported values' -or $msg -match 'RuleValidationException') {
                    Write-PSFMessage -Level Warning -Message "State '$candidateState' is not supported for '$($SourceWorkItem.'System.WorkItemType')' in target. Attempting fallback."

                    $validStates = & $getValidStates $TargetProjectName $SourceWorkItem.'System.WorkItemType'
                    if ($validStates.Count -gt 0) {
                        # Try category-based mapping first (match same stateCategory as original if possible)
                        $origCategory = ($validStates | Where-Object { $_.name -eq $originalState }).stateCategory
                        $fallback = $null

                        if ($origCategory) {
                            $fallback = ($validStates | Where-Object stateCategory -eq $origCategory | Sort-Object order | Select-Object -First 1)
                        }
                        if (-not $fallback) {
                            # Default to the first by 'order'
                            $fallback = ($validStates | Sort-Object order | Select-Object -First 1)
                        }

                        if ($fallback -and $fallback.name -ne $candidateState -and $attemptQueue -notcontains $fallback.name) {
                            Write-PSFMessage -Level Verbose -Message "Selected fallback state '$($fallback.name)' (category=$($fallback.stateCategory))."
                            $attemptQueue.Add($fallback.name)
                        } else {
                            Write-PSFMessage -Level Warning -Message "Unable to determine fallback state."
                        }
                    } else {
                        Write-PSFMessage -Level Warning -Message "No available states retrieved for fallback."
                    }
                }
                else {
                    Write-PSFMessage -Level Error -Message "Non-state error while creating work item $($SourceWorkItem.'System.Id'): $msg"
                    break
                }
            }
        }

        if (-not $created) {
            Write-PSFMessage -Level Error -Message "Failed to create target work item for source ID $($SourceWorkItem.'System.Id'). Last error: $($lastError)"
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Host -Message "Completed processing of work item ID: $($SourceWorkItem.'System.Id')."
    }
}