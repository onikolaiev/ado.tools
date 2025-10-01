
<#
    .SYNOPSIS
        Processes (creates/updates) a source work item in the target org and optionally migrates its attachments.
    .DESCRIPTION
        Idempotent: if work item already exists (detected via mapping or tracking field) it is reused; attachments are deduplicated by filename; comments are appended only if not already present.
        Steps: (1) ensure parent link, (2) locate existing target by Custom.SourceWorkitemId (WIQL) if not mapped, (3) create WI without state if still missing, (4) patch mapped state, (5) migrate attachments (rel='AttachedFile'), (6) migrate comments.
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
    .PARAMETER MigrateComments
        Enable comment migration (default $true). Comments matched by exact text; duplicates skipped.
    .PARAMETER RewriteInlineAttachmentLinks
        When $true (default) scans Description and comment bodies for source attachment URLs and rewrites links to already-migrated (relation-based or inline-downloaded) target URLs.
    .PARAMETER DownloadInlineAttachments
        When $true (default) and RewriteInlineAttachmentLinks is enabled, if an attachment URL is referenced inline (Description/comment) but the GUID was not part of migrated relations, the attachment is downloaded from source and uploaded to target before rewriting the link. Set to $false to only rewrite links for attachments that were already migrated via relations.
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
        [Parameter()][string]$AttachmentTempFolder = (Join-Path $env:TEMP 'ado.tools.attachments'),
        [Parameter()][bool]$MigrateComments = $true,
        [Parameter()][bool]$RewriteInlineAttachmentLinks = $true,
        [Parameter()][bool]$DownloadInlineAttachments = $true
    )

    begin {
        Write-PSFMessage -Level Host -Message "Processing work item ID: $($SourceWorkItem.'System.Id'). Title: $($SourceWorkItem.'System.Title')."
        if (-not $script:ADOValidWorkItemStatesCache) { $script:ADOValidWorkItemStatesCache = @{} }
        if (-not $script:ADOWorkItemProcessingAttempts) { $script:ADOWorkItemProcessingAttempts = @{} }
    }

    process {
            # Local helper to sanitize filenames (remove invalid chars, trim, limit length, ensure not empty)
            if (-not (Get-Variable -Name ADOInlineFileNameSanitizer -Scope Script -ErrorAction SilentlyContinue)) {
                $script:ADOInlineFileNameSanitizer = {
                    param([string]$Name,[switch]$VerboseLog)
                    $original = $Name
                    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = 'attachment.bin' }
                    $invalid = [IO.Path]::GetInvalidFileNameChars()
                    $sb = New-Object System.Text.StringBuilder
                    foreach ($ch in $Name.ToCharArray()) {
                        if ($invalid -contains $ch) { [void]$sb.Append('_') } else { [void]$sb.Append($ch) }
                    }
                    $out = $sb.ToString()
                    # Collapse whitespace, trim, drop trailing dots/spaces
                    $out = ($out -replace '\s+', ' ').Trim().TrimEnd('.', ' ')
                    if (-not $out) { $out = 'attachment.bin' }
                    # Keep only last extension; treat earlier extensions as part of base (replace '.' with '_')
                    $lastDot = $out.LastIndexOf('.')
                    if ($lastDot -gt 0 -and $lastDot -lt ($out.Length - 1)) {
                        $ext = $out.Substring($lastDot)
                        $base = $out.Substring(0,$lastDot)
                        # Replace inner dots in base with '_'
                        if ($base.Contains('.')) { $base = $base -replace '\.+','_' }
                        # If base now ends with space or underscore, trim
                        $base = $base.Trim().TrimEnd('_','.')
                        # Remove duplicate extension tokens accidentally appended (e.g. name_pdf pdf -> name_pdf)
                        $commonExts = 'png','jpg','jpeg','gif','pdf','doc','docx','xls','xlsx','ppt','pptx','txt','log','csv','zip','7z','rar','json','xml','html','htm','md','bmp','svg','vsdx','msg','eml'
                        # If base ends with _<ext> where <ext> equals current ext (without dot) AND ext appears twice originally, collapse it
                        $extNoDot = $ext.TrimStart('.')
                        if ($commonExts -contains $extNoDot -and $base -match "_${extNoDot}$") {
                            $base = $base -replace "_${extNoDot}$",""
                        }
                        $out = "$base$ext"
                    }
                    # Limit length (preserve extension if possible)
                    $max = 120
                    if ($out.Length -gt $max) {
                        $ext2 = [IO.Path]::GetExtension($out)
                        $base2 = [IO.Path]::GetFileNameWithoutExtension($out)
                        $room = $max - $ext2.Length
                        if ($room -le 0) { $out = $out.Substring(0, $max) }
                        else { if ($base2.Length -gt $room) { $base2 = $base2.Substring(0, $room) }; $out = $base2 + $ext2 }
                    }
                    if ($VerboseLog) { Write-PSFMessage -Level Verbose -Message "Sanitized inline filename Original='$original' -> '$out'" }
                    return $out
                }
            }
            # Ensure parent processed (even for existing items found via WIQL) BEFORE creation / lookup logic
            if ($SourceWorkItem.'System.Parent' -and -not $TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']) {
                if (-not $script:ADOWorkItemProcessingAttempts.ContainsKey($SourceWorkItem.'System.Parent')) {
                    try {
                        $allSourceItems = Get-ADOSourceWorkItemsList -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken
                        $parentItem = $allSourceItems | Where-Object { $_.'System.Id' -eq $SourceWorkItem.'System.Parent' }
                        if ($parentItem) {
                            $script:ADOWorkItemProcessingAttempts[$SourceWorkItem.'System.Parent'] = 1
                            Invoke-ADOWorkItemsProcessing -SourceWorkItem $parentItem -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -TargetOrganization $TargetOrganization -TargetProjectName $TargetProjectName -TargetToken $TargetToken -TargetWorkItemList $TargetWorkItemList -ApiVersion $ApiVersion -MigrateAttachments:$MigrateAttachments -AttachmentTempFolder $AttachmentTempFolder -MigrateComments:$MigrateComments -RewriteInlineAttachmentLinks:$RewriteInlineAttachmentLinks -DownloadInlineAttachments:$DownloadInlineAttachments
                        }
                    } catch { Write-PSFMessage -Level Verbose -Message "Parent pre-processing failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                }
            }
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
                    # Attempt to discover existing target work item via tracking field WIQL (safety if map not pre-populated)
                    try {
                        $sourceIdForLookup = $SourceWorkItem.'System.Id'
                        # Some custom fields are stored as string. Try quoted first, then unquoted.
                        # Treat tracking field as string (previous numeric comparison produced TF212023). Always quote.
                        $lookupQueries = @(
                            "SELECT [System.Id] FROM WorkItems WHERE [Custom.SourceWorkitemId] = '$sourceIdForLookup'"
                        )
                        foreach ($q in $lookupQueries) {
                            try {
                                $lookupResult = Invoke-ADOWiqlQueryByWiql -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Query $q -ApiVersion $ApiVersion
                                if ($lookupResult.workItems.Count -gt 0) {
                                    $foundId = $lookupResult.workItems[0].id
                                    $resolved = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $foundId -Expand Relations -ApiVersion $ApiVersion
                                    if ($resolved.url) {
                                        $createdItem = $resolved
                                        $existingTargetUrl = $resolved.url
                                        $TargetWorkItemList.Value[$SourceWorkItem.'System.Id'] = $existingTargetUrl
                                        Write-PSFMessage -Level Host -Message "Found existing work item ID: $($foundId). Skipping creation."
                                        break
                                    }
                                }
                            } catch {
                                Write-PSFMessage -Level Verbose -Message "Lookup query variant failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)"
                            }
                        }
                    } catch { Write-PSFMessage -Level Verbose -Message "Tracking field lookup wrapper failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                    if (-not $existingTargetUrl) {
                        $creationBody = & $buildPatchBody $null
                        Write-PSFMessage -Level Host -Message "Creating work item (no explicit state) SourceID=$($SourceWorkItem.'System.Id')."
                        try {
                            $createdItem = Add-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Type "`$$($SourceWorkItem.'System.WorkItemType')" -Body $creationBody -ApiVersion $ApiVersion -ErrorAction Stop
                            if ($createdItem.url) { $TargetWorkItemList.Value[$SourceWorkItem.'System.Id'] = $createdItem.url }
                            # Verify tracking field actually persisted; if not, warn (avoids silent duplicate creation on reruns)
                            try {
                                $verify = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -ApiVersion $ApiVersion
                                $trackedVal = $verify.fields.'Custom.SourceWorkitemId'
                                if (-not $trackedVal) {
                                    Write-PSFMessage -Level Warning -Message "Tracking field 'Custom.SourceWorkitemId' not present on target item ID=$($createdItem.id). Ensure field is added to process & work item type. Duplicates may occur on reruns."
                                }
                            } catch { Write-PSFMessage -Level Verbose -Message "Post-create verification failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                        } catch { Write-PSFMessage -Level Error -Message "Create failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                    }
                } else {
                Write-PSFMessage -Level Verbose -Message "SourceID=$($SourceWorkItem.'System.Id') already mapped. Skipping creation."
                try { $existingId = [int]($existingTargetUrl.Split('/')[-1]); $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $existingId -Expand Relations -ApiVersion $ApiVersion } catch { Write-PSFMessage -Level Verbose -Message "Lookup of existing target work item failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
            }

            if ($createdItem -and $createdItem.url) {
                $isNew = (-not $existingTargetUrl)
                if ($isNew -and $autoMappedState) {
                    $current = $createdItem.fields.'System.State'
                    if ($autoMappedState -and $autoMappedState -ne $current) {
                        try {
                            $patchBody = @(@{ op='add'; path='/fields/System.State'; value="$autoMappedState" }) | ConvertTo-Json -Depth 4
                            # State patch (JSON Patch array string). Body should be the JSON string, not wrapped in an extra array.
                            Update-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Id $createdItem.id -Body [$patchBody] -ApiVersion $ApiVersion | Out-Null
                            try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch { Write-PSFMessage -Level Verbose -Message "Post-state refresh failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                        } catch { Write-PSFMessage -Level Warning -Message "State patch failed (SourceID=$($SourceWorkItem.'System.Id')): $($_.Exception.Message)" }
                    }
                }

                # Ensure parent relation exists for existing items (if not added during creation)
                if ($SourceWorkItem.'System.Parent') {
                    $parentTarget = $TargetWorkItemList.Value[$SourceWorkItem.'System.Parent']
                    if ($parentTarget) {
                        try {
                            if (-not $createdItem.relations) { try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch {} }
                            $hasParent = $false
                            if ($createdItem.relations) {
                                $hasParent = ($createdItem.relations | Where-Object { $_.rel -eq 'System.LinkTypes.Hierarchy-Reverse' -and $_.url -eq $parentTarget })
                            }
                            if (-not $hasParent) {
                                try {
                                    $rev = $createdItem.rev
                                    $patch = @(
                                        @{ op='test'; path='/rev'; value=$rev },
                                        @{ op='add'; path='/relations/-'; value=@{ rel='System.LinkTypes.Hierarchy-Reverse'; url=$parentTarget; attributes=@{ comment='Parent link (post-create)'} } }
                                    ) | ConvertTo-Json -Depth 6
                                    Update-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Id $createdItem.id -Body $patch -ApiVersion $ApiVersion | Out-Null
                                    try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch {}
                                    Write-PSFMessage -Level Verbose -Message "Added missing parent relation SourceID=$($SourceWorkItem.'System.Id') -> Parent=$($SourceWorkItem.'System.Parent')"
                                } catch { Write-PSFMessage -Level Warning -Message "Failed to add parent relation SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                            }
                        } catch { Write-PSFMessage -Level Verbose -Message "Parent relation ensure failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                    }
                }

            # Map source attachment GUID -> target attachment URL (for relation + inline rewriting)
            $attachmentMap = @{}

            if ($MigrateAttachments) {
                    try {
                        $sourceAttachments = @($SourceWorkItem.Relations | Where-Object { $_.rel -eq 'AttachedFile' })
                        if ($sourceAttachments.Count -gt 0) {
                            if (-not (Test-Path -LiteralPath $AttachmentTempFolder)) { $null = New-Item -ItemType Directory -Force -Path $AttachmentTempFolder }
                            if (-not $createdItem.relations) { try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch { Write-PSFMessage -Level Verbose -Message "Initial relations fetch failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" } }
                            $existingNames = @()
                            if ($createdItem.relations) {
                                $existingNames = @($createdItem.relations | Where-Object rel -eq 'AttachedFile' | ForEach-Object { $_.attributes.name; $_.attributes.resourceName } | Where-Object { $_ }) | Select-Object -Unique
                                $existingNames = $existingNames | ForEach-Object { $_.ToLowerInvariant() }
                            }
                            foreach ($att in $sourceAttachments) {
                                $fileName = $att.attributes.name; if (-not $fileName) { $fileName = $att.attributes.resourceName }; if (-not $fileName) { $fileName = 'attachment.bin' }
                                $norm = $fileName.ToLowerInvariant()
                                if ($existingNames -contains $norm) { continue }
                                $attUrl = $att.url
                                # Extract the attachment id specifically AFTER the '/_apis/wit/attachments/' segment.
                                if ($attUrl -match '/_apis/wit/attachments/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})(?:[/?]|$)') {
                                    $attId = $Matches[1]
                                } else {
                                    Write-PSFMessage -Level Verbose -Message "Skip attachment: could not parse attachment id from URL '$attUrl'"
                                    continue
                                }
                                $downloadPath = Join-Path $AttachmentTempFolder $fileName
                                try {
                                    Get-ADOWorkItemAttachment -Organization $SourceOrganization -Token $SourceToken -Id $attId -OutFile $downloadPath -ApiVersion $ApiVersion | Out-Null
                                    $uploaded = Add-ADOWorkItemAttachment -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -FilePath $downloadPath -FileName $fileName -ApiVersion $ApiVersion
                                    $rev = $createdItem.rev
                                    $patch = @(
                                        @{ op='test'; path='/rev'; value=$rev },
                                        @{ op='add'; path='/relations/-'; value=@{ rel='AttachedFile'; url=$uploaded.url; attributes=@{ comment="Migrated from source $($SourceWorkItem.'System.Id')"; name=$fileName } } }
                                    ) | ConvertTo-Json -Depth 8
                                    Update-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Id $createdItem.id -Body $patch -ApiVersion $ApiVersion | Out-Null
                                    try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch { Write-PSFMessage -Level Verbose -Message "Post-attachment refresh failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                                    $existingNames += $norm
                                    if ($attId -and $uploaded.url) { $attachmentMap[$attId] = $uploaded.url }
                                } catch { Write-PSFMessage -Level Warning -Message "Attachment '$fileName' failed: $($_.Exception.Message)" }
                            }
                        }
                    } catch { Write-PSFMessage -Level Warning -Message "Attachment phase failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                }

            # Inline attachment link rewriting in Description (with optional fallback download)
            if ($RewriteInlineAttachmentLinks) {
                try {
                    $descOriginal = $createdItem.fields.'System.Description'
                    if ($descOriginal) {
                        $descNew = $descOriginal
                        # $changed removed (we rely on string comparison $descNew -ne $descOriginal)
                        $inlineGuids = [System.Collections.Generic.HashSet[string]]::new()
                        # Pattern 1: Properly quoted <img ... src=".../_apis/wit/attachments/{guid}[?...]" ...>
                        $imgPattern = '(?i)(<img[^>]*?\bsrc\s*=\s*")(?<url>https?://[^"<>]*/_apis/wit/attachments/(?<gid>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[^"<>]*)(")'
                        # Pattern 1b: Broken src attribute missing closing quote before next attribute or tag end
                        # Example: <img src="https://.../attachments/{guid}?fileName=image.png alt=Image>
                        $imgPatternBroken = '(?i)(<img[^>]*?\bsrc\s*=\s*")(?<url>https?://[^"\s<>]*/_apis/wit/attachments/(?<gid>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[^"\s<>]*)(?=\s+[a-z][^>]*>|>)'
                        foreach ($m in [regex]::Matches($descNew, $imgPattern)) { $null = $inlineGuids.Add($m.Groups['gid'].Value) }
                        foreach ($m in [regex]::Matches($descNew, $imgPatternBroken)) { $null = $inlineGuids.Add($m.Groups['gid'].Value) }
                        $descNew = [regex]::Replace($descNew, $imgPattern, { param($m) $g=$m.Groups['gid'].Value; if ($attachmentMap.ContainsKey($g)) { $script:__chg = $true; return $m.Groups[1].Value + $attachmentMap[$g] + $m.Groups[3].Value } else { return $m.Value } })
                        # For broken pattern we inject a closing quote to repair HTML
                        $descNew = [regex]::Replace($descNew, $imgPatternBroken, { param($m) $g=$m.Groups['gid'].Value; if ($attachmentMap.ContainsKey($g)) { $script:__chg = $true; return $m.Groups[1].Value + $attachmentMap[$g] + '"' } else { return $m.Value } })
                        if ($script:__chg) { Remove-Variable __chg -Scope Script -ErrorAction SilentlyContinue }
                        # Pattern 2: Markdown image ![alt](url) or plain link containing attachment GUID
                        # Link / markdown image pattern (exclude whitespace, closing paren/bracket/quote). Using double-quoted PowerShell string to avoid single-quote escaping issues.
                        $linkPattern = "(?i)(https?://[^\s)\]`"']*/_apis/wit/attachments/(?<gid2>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[^\s)\]`"']*)"
                        foreach ($m in [regex]::Matches($descNew, $linkPattern)) { $null = $inlineGuids.Add($m.Groups['gid2'].Value) }
                        # Fallback: download + upload inline-only attachments (not in relations) before second replacement pass.
                        if ($DownloadInlineAttachments -and $inlineGuids.Count -gt 0) {
                            if (-not (Test-Path -LiteralPath $AttachmentTempFolder)) { $null = New-Item -ItemType Directory -Force -Path $AttachmentTempFolder }
                            foreach ($gid in $inlineGuids) {
                                if (-not $attachmentMap.ContainsKey($gid)) {
                                    try {
                                        $fileName = "$gid.bin"
                                        $urlMatch = [regex]::Match($descOriginal, "https?://[^\s)\]`"']*/_apis/wit/attachments/$gid[^\s)\]`"']*")
                                        if ($urlMatch.Success) {
                                            $urlVal = $urlMatch.Value.TrimEnd('"')
                                            if ($urlVal -match 'fileName=([^&">]+)') { $fileName = [uri]::UnescapeDataString($Matches[1]) }
                                        }
                                        $fileName = & $script:ADOInlineFileNameSanitizer $fileName
                                        $tmpPath = Join-Path $AttachmentTempFolder $fileName
                                        # Ensure uniqueness if file already exists (parallel names)
                                        $counter = 1
                                        while (Test-Path -LiteralPath $tmpPath) {
                                            $base = [IO.Path]::GetFileNameWithoutExtension($fileName)
                                            $ext  = [IO.Path]::GetExtension($fileName)
                                            $fileName = "$base`_$counter$ext"
                                            $tmpPath = Join-Path $AttachmentTempFolder $fileName
                                            $counter++
                                            if ($counter -gt 50) { break }
                                        }
                                        try {
                                            Get-ADOWorkItemAttachment -Organization $SourceOrganization -Token $SourceToken -Id $gid -OutFile $tmpPath -ApiVersion $ApiVersion -ErrorAction Stop | Out-Null
                                        } catch {
                                            Write-PSFMessage -Level Verbose -Message "Download inline attachment failed guid=$($gid): $($_.Exception.Message)"; continue
                                        }
                                        if (-not (Test-Path -LiteralPath $tmpPath -PathType Leaf)) { continue }
                                        try {
                                            $uploadedInline = Add-ADOWorkItemAttachment -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -FilePath $tmpPath -FileName $fileName -ApiVersion $ApiVersion
                                            if ($uploadedInline.url) { $attachmentMap[$gid] = $uploadedInline.url }
                                        } catch { Write-PSFMessage -Level Verbose -Message "Upload inline attachment failed guid=$($gid): $($_.Exception.Message)" }
                                    } catch { Write-PSFMessage -Level Verbose -Message "Inline attachment fallback failed guid=$gid SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                                }
                            }
                        }
                        $descNew = [regex]::Replace($descNew, $linkPattern, { param($m) $g=$m.Groups['gid2'].Value; if ($attachmentMap.ContainsKey($g)) { return $attachmentMap[$g] } else { return $m.Value } })
                        if ($descNew -ne $descOriginal) {
                            try {
                                $rev = $createdItem.rev
                                $patchOps = @(
                                    @{ op='test'; path='/rev'; value=$rev },
                                    @{ op='replace'; path='/fields/System.Description'; value=$descNew }
                                ) | ConvertTo-Json -Depth 6
                                Update-ADOWorkItem -Organization $TargetOrganization -Token $TargetToken -Project $TargetProjectName -Id $createdItem.id -Body $patchOps -ApiVersion $ApiVersion | Out-Null
                                try { $createdItem = Get-ADOWorkItem -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -Id $createdItem.id -Expand Relations -ApiVersion $ApiVersion } catch {}
                                Write-PSFMessage -Level Verbose -Message "Rewrote inline attachment links in Description SourceID=$($SourceWorkItem.'System.Id')"
                            } catch { Write-PSFMessage -Level Warning -Message "Failed to patch Description inline links SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                        }
                    }
                } catch { Write-PSFMessage -Level Verbose -Message "Inline Description rewrite failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
            }

            if ($MigrateComments) {
                try {
                    # Use existing module cmdlets instead of raw REST calls.
                    $srcComments = @()
                    try { $srcComments = Get-ADOWorkItemCommentList -Organization $SourceOrganization -Project $SourceProjectName -Token $SourceToken -WorkItemId $SourceWorkItem.'System.Id' -All -Order asc -ApiVersion $ApiVersion } catch { Write-PSFMessage -Level Verbose -Message "Source comments fetch failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                    $tgtComments = @()
                    try { $tgtComments = Get-ADOWorkItemCommentList -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -WorkItemId $createdItem.id -All -Order asc -ApiVersion $ApiVersion } catch { Write-PSFMessage -Level Verbose -Message "Target comments fetch failed TargetID=$($createdItem.id): $($_.Exception.Message)" }

                    if ($srcComments.Count -gt 0) {
                        # Determine property holding text (support objects returning .text or .Text)
                        $getText = { param($c) if ($c.PSObject.Properties['text']) { $c.text } elseif ($c.PSObject.Properties['Text']) { $c.Text } else { $null } }
                        $existingCommentTexts = @($tgtComments | ForEach-Object { & $getText $_ }) | Where-Object { $_ } | Select-Object -Unique
                        foreach ($c in $srcComments | Sort-Object id) {
                            $body = & $getText $c
                            if ([string]::IsNullOrWhiteSpace($body)) { continue }
                            if ($existingCommentTexts -contains $body) { continue }
                            try {
                                if ($RewriteInlineAttachmentLinks -and $body) {
                                    $imgPattern = '(?i)(<img[^>]*?\bsrc\s*=\s*")(?<url>https?://[^"<>]*/_apis/wit/attachments/(?<gid>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[^"<>]*)(")'
                                    $imgPatternBroken = '(?i)(<img[^>]*?\bsrc\s*=\s*")(?<url>https?://[^"\s<>]*/_apis/wit/attachments/(?<gid>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[^"\s<>]*)(?=\s+[a-z][^>]*>|>)'
                                    $linkPattern = "(?i)(https?://[^\s)\]`"']*/_apis/wit/attachments/(?<gid2>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[^\s)\]`"']*)"
                                    $inlineGuids = [System.Collections.Generic.HashSet[string]]::new()
                                    foreach ($m in [regex]::Matches($body, $imgPattern)) { $null = $inlineGuids.Add($m.Groups['gid'].Value) }
                                    foreach ($m in [regex]::Matches($body, $imgPatternBroken)) { $null = $inlineGuids.Add($m.Groups['gid'].Value) }
                                    foreach ($m in [regex]::Matches($body, $linkPattern)) { $null = $inlineGuids.Add($m.Groups['gid2'].Value) }
                                    if ($DownloadInlineAttachments -and $inlineGuids.Count -gt 0) {
                                        if (-not (Test-Path -LiteralPath $AttachmentTempFolder)) { $null = New-Item -ItemType Directory -Force -Path $AttachmentTempFolder }
                                        foreach ($gid in $inlineGuids) {
                                            if (-not $attachmentMap.ContainsKey($gid)) {
                                                try {
                                                    $fileName = "$gid.bin"
                                                    $urlMatch = [regex]::Match($body, "https?://[^\s)\]`"']*/_apis/wit/attachments/$gid[^\s)\]`"']*")
                                                    if ($urlMatch.Success) {
                                                        $urlVal = $urlMatch.Value.TrimEnd('"')
                                                        if ($urlVal -match 'fileName=([^&">]+)') { $fileName = [uri]::UnescapeDataString($Matches[1]) }
                                                    }
                                                    $fileName = & $script:ADOInlineFileNameSanitizer $fileName
                                                    $tmpPath = Join-Path $AttachmentTempFolder $fileName
                                                    $counter = 1
                                                    while (Test-Path -LiteralPath $tmpPath) {
                                                        $base = [IO.Path]::GetFileNameWithoutExtension($fileName)
                                                        $ext  = [IO.Path]::GetExtension($fileName)
                                                        $fileName = "$base`_$counter$ext"
                                                        $tmpPath = Join-Path $AttachmentTempFolder $fileName
                                                        $counter++; if ($counter -gt 50) { break }
                                                    }
                                                    try {
                                                        Get-ADOWorkItemAttachment -Organization $SourceOrganization -Token $SourceToken -Id $gid -OutFile $tmpPath -ApiVersion $ApiVersion -ErrorAction Stop | Out-Null
                                                    } catch { Write-PSFMessage -Level Verbose -Message "Download inline comment attachment failed guid=$($gid): $($_.Exception.Message)"; continue }
                                                    if (-not (Test-Path -LiteralPath $tmpPath -PathType Leaf)) { continue }
                                                    try {
                                                        $uploadedInline = Add-ADOWorkItemAttachment -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -FilePath $tmpPath -FileName $fileName -ApiVersion $ApiVersion
                                                        if ($uploadedInline.url) { $attachmentMap[$gid] = $uploadedInline.url }
                                                    } catch { Write-PSFMessage -Level Verbose -Message "Upload inline comment attachment failed guid=$($gid): $($_.Exception.Message)" }
                                                } catch { Write-PSFMessage -Level Verbose -Message "Inline comment attachment fallback failed guid=$gid SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                                            }
                                        }
                                    }
                                    $body = [regex]::Replace($body, $imgPattern, { param($m) $g=$m.Groups['gid'].Value; if ($attachmentMap.ContainsKey($g)) { return $m.Groups[1].Value + $attachmentMap[$g] + $m.Groups[3].Value } else { return $m.Value } })
                                    $body = [regex]::Replace($body, $imgPatternBroken, { param($m) $g=$m.Groups['gid'].Value; if ($attachmentMap.ContainsKey($g)) { return $m.Groups[1].Value + $attachmentMap[$g] + '"' } else { return $m.Value } })
                                    $body = [regex]::Replace($body, $linkPattern, { param($m) $g=$m.Groups['gid2'].Value; if ($attachmentMap.ContainsKey($g)) { return $attachmentMap[$g] } else { return $m.Value } })
                                }
                                $fullBody = "*(Migrated comment from $($c.createdBy.displayName) on $($c.modifiedDate.ToString('u')))*`n`n$body"
                                $null = Add-ADOWorkItemComment -Organization $TargetOrganization -Project $TargetProjectName -Token $TargetToken -WorkItemId $createdItem.id -Text $fullBody -Format markdown -ApiVersion $ApiVersion
                                $existingCommentTexts += $body
                            } catch { Write-PSFMessage -Level Warning -Message "Failed to add comment for SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
                        }
                    }
                } catch { Write-PSFMessage -Level Warning -Message "Comment phase failed SourceID=$($SourceWorkItem.'System.Id'): $($_.Exception.Message)" }
            }
        } else {
                Write-PSFMessage -Level Error -Message "Failed to create or retrieve target work item for SourceID=$($SourceWorkItem.'System.Id')"
        }
    }

    end { Write-PSFMessage -Level Host -Message "Completed processing of work item ID: $($SourceWorkItem.'System.Id')." }
}