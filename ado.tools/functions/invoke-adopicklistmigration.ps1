
<#
    .SYNOPSIS
        Migrates picklists.
    .DESCRIPTION
        This function migrates picklists from a source Azure DevOps organization to a target Azure DevOps organization.
        It copies all picklist items from the source to the target, preserving their properties.
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
    .PARAMETER SourceToken
        The authentication token for accessing the source Azure DevOps organization.
    .PARAMETER TargetToken
        The authentication token for accessing the target Azure DevOps organization.
    .PARAMETER TargetProcess
        The target process object containing details about the process to migrate to.
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOPickListMigration {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][pscustomobject]$TargetProcess,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    Convert-FSCPSTextToAscii -Text "Migrate picklists.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting to process picklists."
    $source = Get-ADOPickListList -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion
    $target = Get-ADOPickListList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion
    foreach ($pl in $source) {
        if (-not $pl) { continue }
        if ([string]::IsNullOrWhiteSpace($pl.id) -or [string]::IsNullOrWhiteSpace($pl.name)) {
            Write-PSFMessage -Level Verbose -Message "Encountered picklist with empty id or name. Skipping. Raw: $($pl | ConvertTo-Json -Depth 5)"
            continue
        }
        Write-PSFMessage -Level Host -Message "Checking picklist '$($pl.name)' in target process."
        $existing = $target.Where({$_.name -eq $pl.name})
        if (-not $existing) {
            Write-PSFMessage -Level Verbose -Message "Picklist '$($pl.name)' does not exist. Adding."
            try {
                $src = Get-ADOPickList -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ListId $pl.id -ErrorAction Stop
            }
            catch {
                Write-PSFMessage -Level Warning -Message "Failed to retrieve picklist id '$($pl.id)': $($_.Exception.Message). Skipping."
                continue
            }
            if (-not $src) { continue }
            $body = @{ name=$src.name; type=$src.type; isSuggested=$src.isSuggested; items=$src.items } | ConvertTo-Json -Depth 10
            Write-PSFMessage -Level Host -Message "Adding picklist '$($src.name)' to target process '$($TargetProcess.name)'."
            try {
                $added = Add-ADOPickList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -Body $body -ErrorAction Stop
                if ($added) { $target += $added }
            }
            catch {
                Write-PSFMessage -Level Error -Message "Failed to add picklist '$($src.name)': $($_.Exception.Message)"
            }
        } else {
            Write-PSFMessage -Level Host -Message "Picklist '$($pl.name)' already exists. Skipping."
        }
    }
}