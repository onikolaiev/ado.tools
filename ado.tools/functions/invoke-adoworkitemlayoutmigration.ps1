
<#
    .SYNOPSIS
        Migrates layouts (pages, sections, groups, controls).
    .DESCRIPTION
        This function migrates work item type layouts from a source process to a target process within Azure DevOps.
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
    .PARAMETER SourceToken
        The authentication token for accessing the source Azure DevOps organization.
    .PARAMETER TargetToken
        The authentication token for accessing the target Azure DevOps organization.
    .PARAMETER SourceProcess
        The source process object containing details about the process to migrate from.
    .PARAMETER TargetProcess
        The target process object containing details about the process to migrate to.
    .PARAMETER SourceWitList
        The list of work item types in the source process.
    .PARAMETER TargetWitList
        The list of work item types in the target process.
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
        
        Invoke-ADOWorkItemLayoutMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess `
            -SourceWitList $witResult.SourceList -TargetWitList $witResult.TargetList -ApiVersion $apiVersion
        # Recreates custom pages/sections/groups/controls for inherited WITs.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOWorkItemLayoutMigration {
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
    Convert-FSCPSTextToAscii -Text "Migrate layouts.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting to process layouts."
    foreach ($wit in $SourceWitList) {
        Write-PSFMessage -Level Host -Message "Processing layouts for WIT '$($wit.name)'."
        $targetWit = $TargetWitList.Where({$_.name -eq $wit.name})
        if (-not $targetWit) { continue }
        $srcLayout = Get-ADOWorkItemTypeLayout -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName
        $tgtLayout = Get-ADOWorkItemTypeLayout -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName
        foreach ($page in $srcLayout.pages | Where-Object pageType -eq 'custom') {
            Write-PSFMessage -Level Host -Message "Processing page '$($page.label)'."
            $tgtPage = $tgtLayout.pages.Where({$_.label -eq $page.label})
            if (-not $tgtPage) {
                $body = @{ id=$page.id; label=$page.label; pageType=$page.pageType; visible=$page.visible } | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Verbose -Message "Adding page '$($page.label)'."
                $tgtPage = Add-ADOWorkItemTypePage -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -Body $body
            } else {
                $body = @{ id=$tgtPage.id; label=$page.label; pageType=$page.pageType; visible=$page.visible } | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Verbose -Message "Updating page '$($page.label)'."
                $null = Update-ADOWorkItemTypePage -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -Body $body
            }
            $tgtPage = Get-ADOWorkItemTypeLayout -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName | Select-Object -ExpandProperty pages | Where-Object label -eq $page.label
            foreach ($section in ($page.sections | Where-Object groups -ne $null)) {
                $tgtSection = $tgtPage.sections.Where({$_.id -eq $section.id})
                if (-not $tgtSection) {
                    $body = @{ id=$section.id; label=$section.label; visible=$section.visible } | ConvertTo-Json -Depth 10
                    Write-PSFMessage -Level Verbose -Message "Adding section '$($section.label)' on page '$($page.label)'."
                    $tgtSection = Add-ADOWorkItemTypeSection -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -PageId $tgtPage.id -Body $body
                }
                foreach ($group in $section.groups) {
                    $tgtGroup = $tgtSection.groups.Where({$_.label -eq $group.label})
                    if (-not $tgtGroup) {
                        $body = @{ id=$group.id; label=$group.label; visible=$group.visible; controls=$group.controls } | ConvertTo-Json -Depth 10
                        Write-PSFMessage -Level Verbose -Message "Adding group '$($group.label)' in section '$($section.label)'."
                        $tgtGroup = Add-ADOWorkItemTypeGroup -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -PageId $tgtPage.id -SectionId $section.id -Body $body
                    }
                    foreach ($control in $group.controls) {
                        $tgtControl = $tgtGroup.controls.Where({$_.id -eq $control.id})
                        if (-not $tgtControl) {
                            $body = @{ id=$control.id; label=$control.label; controlType=$control.controlType; contribution=$control.contribution; visible=$control.visible; height=$control.height; readOnly=$control.readOnly } | ConvertTo-Json -Depth 10
                            Write-PSFMessage -Level Verbose -Message "Adding control '$($control.id)' in group '$($group.label)'."
                            $null = Add-ADOWorkItemTypeGroupControl -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -GroupId $tgtGroup.id -Body $body
                        }
                    }
                }
            }
        }
    }
}