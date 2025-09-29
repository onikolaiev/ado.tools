
<#
    .SYNOPSIS
        Processes (creates/updates) a source work item in the target org and optionally migrates its attachments.
    .DESCRIPTION
        Idempotent: if work item already created (mapping exists) it is reused; attachments are deduplicated by filename.
        Steps: (1) ensure parent link, (2) create WI without state, (3) patch mapped state, (4) migrate attachments (rel='AttachedFile').
    .PARAMETER SourceWorkItem
        Source work item object (fields + Relations if migrating attachments).
    .PARAMETER SourceOrganization
        Source organization name.
    .PARAMETER SourceProjectName
        Source project name.
    .PARAMETER SourceToken
        Source PAT.
    .PARAMETER TargetOrganization
        Target organization name.
    .PARAMETER TargetProjectName
        Target project name.
    .PARAMETER TargetToken
        Target PAT (needs write & attachment scopes).
    .PARAMETER TargetWorkItemList
        Reference to hashtable mapping SourceId -> target WI URL.
    .PARAMETER ApiVersion
        API version (default module value).
    .PARAMETER MigrateAttachments
        Enable attachment migration (default $true).
    .PARAMETER AttachmentTempFolder
        Temp folder for downloaded attachments.
    .EXAMPLE
        Invoke-ADOWorkItemsProcessing -SourceWorkItem $wi -SourceOrganization src -SourceProjectName proj -SourceToken $patSrc `
            -TargetOrganization tgt -TargetProjectName proj2 -TargetToken $patTgt -TargetWorkItemList ([ref]$map)
        
        Processes a single work item, creating it in the target if not already mapped, migrating attachments if enabled.
    .NOTES
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOWorkItemsProcessing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$SourceWorkItem,
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$SourceProjectName,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$TargetProjectName,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][ref]$TargetWorkItemList,
        [Parameter()][string]$ApiVersion = $Script:ADOApiVersion,
        [Parameter()][bool]$MigrateAttachments = $true,
        [Parameter()][string]$AttachmentTempFolder = (Join-Path $env:TEMP 'ado.tools.attachments')
    )

    begin {
        Write-PSFMessage -Level Host -Message "Processing work item ID: $($SourceWorkItem.'System.Id'). Title: $($SourceWorkItem.'System.Title')."
        if (-not $script:ADOValidWorkItemStatesCache) { $script:ADOValidWorkItemStatesCache = @{} }
        if (-not $script:ADOWorkItemProcessingAttempts) { $script:ADOWorkItemProcessingAttempts = @{} }
    }

    process {
            $buildPatchBody = {
                param($stateValue)
                $ops = @(
                    @{ op='add'; path='/fields/System.Title';        value = "$($SourceWorkItem.'System.Title')" }
                    @{ op='add'; path='/fields/System.Description';  value = "$($SourceWorkItem.'System.Description')" }
                    @{ op='add'; path='/fields/Custom.SourceWorkitemId'; value = "$($SourceWorkItem.'System.Id')" }
                )
                if ($stateValue) { $ops += @{ op='add'; path='/fields/System.State'; value=$stateValue } }
                $ops = $ops | Where-Object { if ($_.path -eq '/fields/System.Description' -and [string]::IsNullOrWhiteSpace($_.value)) { $false } else { $true } }
                if ($SourceWorkItem.'System.Parent') {
                    if (-not $TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']) {
                        if (-not $script:ADOWorkItemProcessingAttempts.ContainsKey($SourceWorkItem.'System.Parent')) {
                            $allSourceItems = Get-ADOSourceWorkItemsList -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken
                            $parentItem = $allSourceItems | Where-Object { $_.'System.Id' -eq $SourceWorkItem.'System.Parent' }
                            if ($parentItem) {
                                $script:ADOWorkItemProcessingAttempts[$SourceWorkItem.'System.Parent'] = 1
                                Invoke-ADOWorkItemsProcessing -SourceWorkItem $parentItem -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -TargetOrganization $TargetOrganization -TargetProjectName $TargetProjectName -TargetToken $TargetToken -TargetWorkItemList $TargetWorkItemList -ApiVersion $ApiVersion -MigrateAttachments:$MigrateAttachments -AttachmentTempFolder $AttachmentTempFolder
                            }
                        }
                    }
                    if ($TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']) {
                        $ops += @{ op='add'; path='/relations/-'; value=@{ rel='System.LinkTypes.Hierarchy-Reverse'; url=$TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']; attributes=@{ comment='Parent link' } } }
                    }
                }
                $ops | ConvertTo-Json -Depth 10
            }

        $existingTargetUrl = $TargetWorkItemList.Value[$SourceWorkItem.'System.Id']
        $createdItem = $null

            $originalState = $SourceWorkItem.'System.State'
            $witType = $SourceWorkItem.'System.WorkItemType'
            $autoMappedState = $null
            if ($script:ADOStateAutoMap) {
                $mappingKey = "$witType|$originalState"
                if ($script:ADOStateAutoMap.ContainsKey($mappingKey)) {
                    $autoMappedState = $script:ADOStateAutoMap[$mappingKey]
                    if ($autoMappedState -and $autoMappedState -ne $originalState) { Write-PSFMessage -Level Verbose -Message "Auto-mapped '$originalState' -> '$autoMappedState' for type '$witType'." }
                }
            }

        if (-not $existingTargetUrl) {
                $creationBody = & $buildPatchBody $null
                Write-PSFMessage -Level Verbose -Message "Phase 1: Creating work item (no explicit state) SourceID=$($SourceWorkItem.'System.Id')."
                try {
                    $createdItem = Add-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Type "`$$($SourceWorkItem.'System.WorkItemType')" -Body $creationBody -ApiVersion $ApiVersion -ErrorAction Stop
                    if ($createdItem.url) { $TargetWorkItemList.Value[$SourceWorkItem.'System.Id'] = $createdItem.url }
                } catch { Write-PSFMessage -Level Error -Message "Create failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
            } else {
                Write-PSFMessage -Level Verbose -Message "SourceID=$($SourceWorkItem.'System.Id') already mapped. Skipping creation."
                try { $existingId = [int]($existingTargetUrl.Split('/')[-1]); $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $existingId -Expand Relations -ApiVersion $ApiVersion } catch {}
            }

        if ($createdItem -and $createdItem.url) {
                $isNew = (-not $existingTargetUrl)
                if ($isNew -and $autoMappedState) {
                    $current = $createdItem.fields.'System.State'
                    if ($autoMappedState -and $autoMappedState -ne $current) {
                        try {
                            $patchBody = @(@{ op='add'; path='/fields/System.State'; value="$autoMappedState" }) | ConvertTo-Json -Depth 4
                            Update-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Id $createdItem.id -Body [$patchBody] -ApiVersion $ApiVersion | Out-Null
                            try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch {}
                        } catch { Write-PSFMessage -Level Warning -Message "State patch failed (SourceID=$($SourceWorkItem.'System.Id')): $($_.Exception.Message)" }
                    }
                }

            if ($MigrateAttachments) {
                    try {
                        $sourceAttachments = @($SourceWorkItem.Relations | Where-Object { $_.rel -eq 'AttachedFile' })
                        if ($sourceAttachments.Count -gt 0) {
                            if (-not (Test-Path -LiteralPath $AttachmentTempFolder)) { $null = New-Item -ItemType Directory -Force -Path $AttachmentTempFolder }
                            if (-not $createdItem.relations) { try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch {} }
                            $existingNames = @()
                            if ($createdItem.relations) {
                                $existingNames = @($createdItem.relations | Where-Object rel -eq 'AttachedFile' | ForEach-Object { $_.attributes.name; $_.attributes.resourceName } | Where-Object { $_ }) | Select-Object -Unique
                                $existingNames = $existingNames | ForEach-Object { $_.ToLowerInvariant() }
                            }
                            foreach ($att in $sourceAttachments) {
                                $fileName = $att.attributes.name; if (-not $fileName) { $fileName = $att.attributes.resourceName }; if (-not $fileName) { $fileName = 'attachment.bin' }
                                $norm = $fileName.ToLowerInvariant()
                                if ($existingNames -contains $norm) { continue }
                                $attUrl = $att.url; if ($attUrl -notmatch '([0-9a-fA-F-]{36})') { continue }; $attId = $Matches[1]
                                $downloadPath = Join-Path $AttachmentTempFolder $fileName
                                try {
                                    Get-ADOWorkItemAttachment -Organization $SourceOrganization -Token $SourceToken -Id $attId -OutFile $downloadPath -ApiVersion $ApiVersion | Out-Null
                                    $uploaded = Add-ADOWorkItemAttachment -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -FilePath $downloadPath -FileName $fileName -ApiVersion $ApiVersion
                                    $rev = $createdItem.rev
                                    $patch = @(
                                        @{ op='test'; path='/rev'; value=$rev },
                                        @{ op='add'; path='/relations/-'; value=@{ rel='AttachedFile'; url=$uploaded.url; attributes=@{ comment="Migrated from source $($SourceWorkItem.'System.Id')"; name=$fileName } } }
                                    ) | ConvertTo-Json -Depth 8
                                    Update-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Id $createdItem.id -Body [$patch] -ApiVersion $ApiVersion | Out-Null
                                    try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch {}
                                    $existingNames += $norm
                                } catch { Write-PSFMessage -Level Warning -Message "Attachment '$fileName' failed: $($_.Exception.Message)" }
                            }
                        }
                    } catch { Write-PSFMessage -Level Warning -Message "Attachment phase failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                }
        } else {
                Write-PSFMessage -Level Error -Message "Failed to create or retrieve target work item for SourceID=$($SourceWorkItem.'System.Id')"
        }
    }

    end { Write-PSFMessage -Level Host -Message "Completed processing of work item ID: $($SourceWorkItem.'System.Id')." }
}