
<#
    .SYNOPSIS
        Migrates teams from source Azure DevOps project to target Azure DevOps project.
        
    .DESCRIPTION
        This function migrates teams from a source Azure DevOps organization/project to a target
        organization/project. It creates teams in the target project if they don't exist,
        preserving team names and descriptions. Optionally migrates team members and settings.
        
    .PARAMETER SourceOrganization
        Source Azure DevOps organization name.
        
    .PARAMETER TargetOrganization
        Target Azure DevOps organization name.
        
    .PARAMETER SourceProjectName
        Source project name or ID.
        
    .PARAMETER TargetProjectName
        Target project name or ID.
        
    .PARAMETER SourceToken
        Source organization Personal Access Token (PAT) with vso.project scope.
        
    .PARAMETER TargetToken
        Target organization Personal Access Token (PAT) with vso.project_manage scope.
        
    .PARAMETER IncludeMembers
        Include team members in migration (requires additional permissions).
        
    .PARAMETER IncludeSettings
        Include team settings like default area path, iteration paths, etc.
        
    .PARAMETER ExcludeDefaultTeam
        Skip migration of the default project team.
        
    .PARAMETER ApiVersion
        API version to use (default: 7.2-preview.3).
        
    .EXAMPLE
        Invoke-ADOTeamMigration -SourceOrganization "contoso" -TargetOrganization "fabrikam" -SourceProjectName "WebApp" -TargetProjectName "WebApp-New" -SourceToken $sourcePat -TargetToken $targetPat
        
        Migrates all teams from source to target project (names and descriptions only).
        
    .EXAMPLE
        Invoke-ADOTeamMigration -SourceOrganization "contoso" -TargetOrganization "fabrikam" -SourceProjectName "WebApp" -TargetProjectName "WebApp-New" -SourceToken $sourcePat -TargetToken $targetPat -IncludeMembers -IncludeSettings
        
        Migrates teams including members and settings.
        
    .EXAMPLE
        Invoke-ADOTeamMigration -SourceOrganization "contoso" -TargetOrganization "fabrikam" -SourceProjectName "WebApp" -TargetProjectName "WebApp-New" -SourceToken $sourcePat -TargetToken $targetPat -ExcludeDefaultTeam
        
        Migrates teams but skips the default project team.
        
    .NOTES
        Author: Oleksandr Nikolaiev (@onikolaiev)
        Requires:
            - Source PAT: vso.project (read)
            - Target PAT: vso.project_manage (write)
            - For members migration: vso.memberentitlementmanagement
        
    .LINK
        https://learn.microsoft.com/azure/devops/organizations/security/about-permissions
#>
function Invoke-ADOTeamMigration {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceProjectName,
        [Parameter(Mandatory)][string]$TargetProjectName,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter()][switch]$IncludeMembers,
        [Parameter()][switch]$IncludeSettings,
        [Parameter()][switch]$ExcludeDefaultTeam,
        [Parameter()][string]$ApiVersion = '7.2-preview.3'
    )

    begin {
        Write-PSFMessage -Level Host -Message "Starting team migration from '$SourceOrganization/$SourceProjectName' to '$TargetOrganization/$TargetProjectName'..."
        
        # Initialize counters
        $stats = @{
            Migrated = 0
            Skipped = 0
            Errors = 0
        }
    }

    process {
        try {
            # Get source teams
            Write-PSFMessage -Level Verbose -Message "Fetching source teams from '$SourceOrganization/$SourceProjectName'..."
            $sourceTeams = Get-ADOProjectTeamList -Organization $SourceOrganization -ProjectId $SourceProjectName -Token $SourceToken -ApiVersion $ApiVersion

            if (-not $sourceTeams -or $sourceTeams.Count -eq 0) {
                Write-PSFMessage -Level Warning -Message "No teams found in source project '$SourceProjectName'."
                return $stats
            }

            Write-PSFMessage -Level Host -Message "Found $($sourceTeams.Count) teams in source project."

            # Get target teams to avoid duplicates
            Write-PSFMessage -Level Verbose -Message "Fetching existing teams from target project..."
            $targetTeams = Get-ADOProjectTeamList -Organization $TargetOrganization -ProjectId $TargetProjectName -Token $TargetToken -ApiVersion $ApiVersion
            $targetTeamNames = @($targetTeams | ForEach-Object { $_.name })

            # Process each source team
            foreach ($sourceTeam in $sourceTeams) {
                $teamName = $sourceTeam.name

                try {
                    # Skip default team if requested
                    if ($ExcludeDefaultTeam -and $sourceTeam.isDefaultTeam) {
                        Write-PSFMessage -Level Verbose -Message "Skipping default team '$teamName' as requested."
                        $stats.Skipped++
                        continue
                    }

                    # Check if team already exists in target
                    if ($targetTeamNames -contains $teamName) {
                        Write-PSFMessage -Level Verbose -Message "Team '$teamName' already exists in target. Skipping creation."
                        $stats.Skipped++
                        continue
                    }

                    Write-PSFMessage -Level Host -Message "Migrating team '$teamName'..."

                    # Get detailed team info from source
                    $sourceTeamDetail = Get-ADOTeam -Organization $SourceOrganization -ProjectId $SourceProjectName -TeamId $sourceTeam.id -Token $SourceToken -ApiVersion $ApiVersion

                    # Create team in target
                    $teamParams = @{
                        Organization = $TargetOrganization
                        ProjectId = $TargetProjectName
                        Token = $TargetToken
                        Name = $teamName
                        ApiVersion = $ApiVersion
                    }

                    if ($sourceTeamDetail.description) {
                        $teamParams.Description = $sourceTeamDetail.description
                    }

                    $newTeam = Add-ADOTeam @teamParams

                    if ($newTeam) {
                        Write-PSFMessage -Level Verbose -Message "Successfully created team '$teamName' with ID '$($newTeam.id)'."
                        $stats.Migrated++

                        # Migrate members if requested
                        if ($IncludeMembers) {
                            try {
                                $memberResult = Invoke-ADOTeamMemberMigration -SourceOrganization $SourceOrganization -TargetOrganization $TargetOrganization -SourceProjectName $SourceProjectName -TargetProjectName $TargetProjectName -SourceToken $SourceToken -TargetToken $TargetToken -SourceTeamId $sourceTeam.id -TargetTeamId $newTeam.id -ApiVersion $ApiVersion
                                Write-PSFMessage -Level Verbose -Message "Team '$teamName' members migration: $($memberResult.Migrated) migrated, $($memberResult.Errors) errors."
                            } catch {
                                Write-PSFMessage -Level Warning -Message "Failed to migrate members for team '$teamName': $($_.Exception.Message)"
                            }
                        }

                        # Migrate settings if requested
                        if ($IncludeSettings) {
                            try {
                                Invoke-ADOTeamSettingsMigration -SourceOrganization $SourceOrganization -TargetOrganization $TargetOrganization -SourceProjectName $SourceProjectName -TargetProjectName $TargetProjectName -SourceToken $SourceToken -TargetToken $TargetToken -SourceTeamId $sourceTeam.id -TargetTeamId $newTeam.id -ApiVersion $ApiVersion
                                Write-PSFMessage -Level Verbose -Message "Team '$teamName' settings migration completed."
                            } catch {
                                Write-PSFMessage -Level Warning -Message "Failed to migrate settings for team '$teamName': $($_.Exception.Message)"
                            }
                        }
                    }
                    else {
                        Write-PSFMessage -Level Warning -Message "Failed to create team '$teamName' - no team object returned."
                        $stats.Errors++
                    }
                }
                catch {
                    Write-PSFMessage -Level Warning -Message "Failed to migrate team '$teamName': $($_.Exception.Message)"
                    $stats.Errors++
                }
            }
        }
        catch {
            Write-PSFMessage -Level Error -Message "Critical error during team migration: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-PSFMessage -Level Host -Message "Team migration completed. Migrated: $($stats.Migrated), Skipped: $($stats.Skipped), Errors: $($stats.Errors)"
        return $stats
    }
}