
<#
    .SYNOPSIS
        Migrates rules for inherited WITs.
    .DESCRIPTION
        Migrates rules assigned to each inherited WIT in process.
        This includes copying rules from the source WITs to the target WITs, ensuring that all customizations are preserved.
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
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOWorkItemRuleMigration {
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
    Convert-FSCPSTextToAscii -Text "Migrate rules.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting to process rules."
    foreach ($wit in $SourceWitList) {
        Write-PSFMessage -Level Host -Message "Processing rules for WIT '$($wit.name)'."
        $targetWit = $TargetWitList.Where({$_.name -eq $wit.name})
        if (-not $targetWit) { continue }
        $sourceRules = (Get-ADOWorkItemTypeRuleList -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName).Where({$_.customizationType -ne 'system'})
        $targetRules = (Get-ADOWorkItemTypeRuleList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName).Where({$_.customizationType -ne 'system'})
        foreach ($rule in $sourceRules) {
            Write-PSFMessage -Level Host -Message "Checking rule '$($rule.name)'."
            if (-not ($targetRules.Where({$_.name -eq $rule.name}))) {
                Write-PSFMessage -Level Host -Message "Rule '$($rule.name)' does not exist. Adding."
                $srcRule = Get-ADOWorkItemTypeRule -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName -RuleRefName $rule.referenceName
                $body = @{ name=$srcRule.name; conditions=$srcRule.conditions; actions=$srcRule.actions; isDisabled=$srcRule.isDisabled } | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Verbose -Message "Adding rule '$($srcRule.name)' to target process '$($TargetProcess.name)' with body: $body"
                $null = Add-ADOWorkItemTypeRule -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -Body $body
            } else {
                Write-PSFMessage -Level Host -Message "Rule '$($rule.name)' already exists. Skipping."
            }
        }
    }
}