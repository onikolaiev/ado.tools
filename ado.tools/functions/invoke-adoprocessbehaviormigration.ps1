
<#
    .SYNOPSIS
        Migrates behaviors between processes.
    .DESCRIPTION
        This function migrates behaviors from a source process to a target process within Azure DevOps.
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
        
        Invoke-ADOProcessBehaviorMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess -ApiVersion $apiVersion
        # Migrates custom (non-system) behaviors.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOProcessBehaviorMigration {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][pscustomobject]$SourceProcess,
        [Parameter(Mandatory)][pscustomobject]$TargetProcess,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    Convert-FSCPSTextToAscii -Text "Migrate behaviors.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting to process behaviors."
    $sourceBehaviors = Get-ADOProcessBehaviorList -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -Expand 'fields'
    $targetBehaviors = Get-ADOProcessBehaviorList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -Expand 'fields'
    foreach ($behavior in $sourceBehaviors) {
        Write-PSFMessage -Level Host -Message "Checking behavior '$($behavior.name)' in target process."
        if (-not ($targetBehaviors.Where({$_.name -eq $behavior.name}))) {
            Write-PSFMessage -Level Verbose -Message "Behavior '$($behavior.name)' does not exist. Adding."
            $src = Get-ADOProcessBehavior -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -BehaviorRefName $behavior.referenceName -Expand 'fields'
            $body = @{ color=$src.color; inherits=$src.inherits; name=$src.name; referenceName=$src.referenceName } | ConvertTo-Json -Depth 10
            Write-PSFMessage -Level Host -Message "Adding behavior '$($src.name)' to target process '$($TargetProcess.name)'."
            $null = Add-ADOProcessBehavior -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -Body $body
        } else {
            Write-PSFMessage -Level Host -Message "Behavior '$($behavior.name)' already exists. Skipping."
        }
    }
}