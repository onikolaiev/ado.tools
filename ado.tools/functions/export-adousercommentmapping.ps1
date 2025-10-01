
<#
    .SYNOPSIS
        Exports a JSON template mapping of distinct source comment authors to target users for later migration.
    
    .DESCRIPTION
        Scans all work item comments in a source Azure DevOps project, collects distinct author email addresses (unique case-insensitive),
        and produces a JSON file with entries:
            - sourceEmail : the detected author (from comment createdBy uniqueName or email)
            - targetEmail : initially empty (to be manually filled before running full migration)
            - targetPat   : initially empty (optional per-user PAT if needed during migration)
        A final node named '@default_user' is appended to serve as fallback mapping when a source user is not explicitly mapped.
        
        The resulting JSON array can be edited and then supplied to future migration logic to impersonate or attribute comments
        according to the mapping (functionality to consume this map is implemented separately).
    .PARAMETER Organization
        Source Azure DevOps organization name.
    .PARAMETER ProjectName
        Source Azure DevOps project name.
    .PARAMETER Token
        Personal Access Token with read access to Work Items & Comments.
    .PARAMETER ApiVersion
        API version to use (defaults to module default if not provided).
    .PARAMETER OutputPath
        Destination path for JSON file. If only a directory is provided, default filename 'ado.commentUserMapping.json' is used.
    .PARAMETER Force
        Overwrite existing output file if present.
    .EXAMPLE
        Export-ADOUserCommentMapping -Organization org -ProjectName Sample -Token $pat -OutputPath C:\temp\comment-map.json
        
        Exports mapping JSON template to C:\temp\comment-map.json
    .EXAMPLE
        Export-ADOUserCommentMapping -Organization org -ProjectName Sample -Token $pat -Verbose
        
        Writes mapping into current directory as ado.commentUserMapping.json
    .NOTES
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Export-ADOUserCommentMapping {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$Organization,
        [Parameter(Mandatory)][string]$ProjectName,
        [Parameter(Mandatory)][string]$Token,
        [Parameter()][string]$ApiVersion = $Script:ADOApiVersion,
        [Parameter()][string]$OutputPath = (Join-Path (Get-Location) 'ado.commentUserMapping.json'),
        [Parameter()][switch]$Force
    )

    begin {
        $msg = "Building comment author mapping for project '{0}' in org '{1}'..." -f $ProjectName, $Organization
        Write-PSFMessage -Level Host -Message $msg
    }

    process {
        try {
            $allIds = @()
            # Enumerate work item ids
            try {
                $sourceItems = Get-ADOSourceWorkItemsList -SourceOrganization $Organization -SourceProjectName $ProjectName -SourceToken $Token -ApiVersion $ApiVersion
                if ($sourceItems) { $allIds = $sourceItems.'System.Id' | Sort-Object -Unique }
            } catch {
                $warn = "Failed to enumerate work items. Error: {0}" -f $_.Exception.Message
                Write-PSFMessage -Level Warning -Message $warn
                return
            }
            if (-not $allIds -or $allIds.Count -eq 0) {
                Write-PSFMessage -Level Warning -Message 'No work items found; mapping will contain only the default node.'
            }
            $authors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($wid in $allIds) {
                try {
                    $comments = Get-ADOWorkItemCommentList -Organization $Organization -Project $ProjectName -Token $Token -WorkItemId $wid -All -Order asc -ApiVersion $ApiVersion
                    if ($comments) {
                        foreach ($c in $comments) {
                            $createdBy = $null
                            if ($c.createdBy) {
                                if ($c.createdBy.PSObject.Properties['uniqueName']) { $createdBy = $c.createdBy.uniqueName }
                                elseif ($c.createdBy.PSObject.Properties['mailAddress']) { $createdBy = $c.createdBy.mailAddress }
                                elseif ($c.createdBy.PSObject.Properties['displayName']) { $createdBy = $c.createdBy.displayName }
                            }
                            $isEmptyAuthor = [string]::IsNullOrWhiteSpace($createdBy)
                            if (-not $isEmptyAuthor) { $null = $authors.Add($createdBy.Trim()) }
                        }
                    }
                } catch {
                    Write-PSFMessage -Level Verbose -Message ("Failed to load comments for work item {0}" -f $wid)
                }
            }
            $list = foreach ($a in ($authors | Sort-Object)) {
                [pscustomobject]@{ sourceEmail = $a; targetEmail = ''; targetPat = '' }
            }
            $list += [pscustomobject]@{ sourceEmail = '@default_user'; targetEmail = ''; targetPat = '' }
            $json = $list | ConvertTo-Json -Depth 4
            $outFile = $OutputPath
            if (Test-Path -LiteralPath $outFile -PathType Container) { $outFile = Join-Path $outFile 'ado.commentUserMapping.json' }
            if ((Test-Path -LiteralPath $outFile) -and -not $Force) {
                throw ("Output file '{0}' already exists. Use -Force to overwrite." -f $outFile)
            }
            $json | Out-File -LiteralPath $outFile -Encoding UTF8 -Force
            Write-PSFMessage -Level Host -Message ("Comment author mapping exported to '{0}'. Entries: {1}." -f $outFile, $list.Count)
        } catch {
            Write-PSFMessage -Level Error -Message ("Export failed. Error: {0}" -f $_.Exception.Message)
        }
    }
}