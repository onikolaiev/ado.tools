
<#
    .SYNOPSIS
        Migrates inherited work item types between processes.
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
        
        $witResult = Invoke-ADOWorkItemTypeMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken `
            -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess -ApiVersion $apiVersion
        # Ensures all inherited custom work item types exist in target.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
        
#>
function Invoke-ADOWorkItemTypeMigration {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][pscustomobject]$SourceProcess,
        [Parameter(Mandatory)][pscustomobject]$TargetProcess,
        [Parameter(Mandatory)][string]$ApiVersion
    )
        [OutputType([hashtable])]
    Convert-FSCPSTextToAscii -Text "Migrate work item types.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Fetching custom work item types from source process '$($SourceProcess.name)'."
    $sourceWits = (Get-ADOWorkItemTypeList -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -Expand layout).Where({$_.customization -eq 'inherited'})
    Write-PSFMessage -Level Host -Message "Found $($sourceWits.Count) custom work item types in source process."

    Write-PSFMessage -Level Host -Message "Fetching custom work item types from target process '$($TargetProcess.name)'."
    $targetWits = (Get-ADOWorkItemTypeList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -Expand layout).Where({$_.customization -eq 'inherited'})
    Write-PSFMessage -Level Host -Message "Found $($targetWits.Count) custom work item types in target process."

    foreach ($wit in $sourceWits) {
        if (-not ($targetWits.Where({$_.name -eq $wit.name}))) {
            Write-PSFMessage -Level Host -Message "Work item type '$($wit.name)' does not exist in target process. Adding it."
            $src = Get-ADOWorkItemType -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName
            $body = @{ name=$src.name; description=$src.description; color=$src.color; icon=$src.icon; isDisabled=$src.isDisabled; inheritsFrom=$src.inherits } | ConvertTo-Json -Depth 10
            Write-PSFMessage -Level Verbose -Message "Adding work item type '$($src.name)' to target process '$($TargetProcess.name)' with body: $body"
            $null = Add-ADOWorkItemType -Organization $TargetOrganization -Token $TargetToken -ProcessId $TargetProcess.typeId -Body $body
        } else {
            Write-PSFMessage -Level Host -Message "Work item type '$($wit.name)' already exists. Skipping."
        }
    }

    $targetWits = (Get-ADOWorkItemTypeList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -Expand layout).Where({$_.customization -eq 'inherited'})
    return @{ SourceList = $sourceWits; TargetList = $targetWits }
}