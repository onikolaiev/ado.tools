
<#
    .SYNOPSIS
        Handles migration (ensure existence) of the process in target org.
    .DESCRIPTION
        Given source project object and tokens, ensures the corresponding inherited process exists in target organization.
        Returns a hashtable with keys SourceProcess, TargetProcess, SourceParentProcess.
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
    .PARAMETER SourceToken
        The authentication token for accessing the source Azure DevOps organization.
    .PARAMETER TargetToken
        The authentication token for accessing the target Azure DevOps organization.
    .PARAMETER SourceProject
        The source project object containing details about the project to migrate.
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use.
    .EXAMPLE
        $apiVersion = '7.1'
        $sourceOrg  = 'srcOrg'
        $targetOrg  = 'tgtOrg'
        $sourceToken = 'pat-src'
        $targetToken = 'pat-tgt'
        $sourceProjectName = 'Sample'
        
        # Lookup source project (same pattern as orchestrator)
        $sourceProjectMeta = (Get-ADOProjectList -Organization $sourceOrg -Token $sourceToken -ApiVersion $apiVersion -StateFilter All) | Where-Object name -eq $sourceProjectName
        $sourceProject = Get-ADOProject -Organization $sourceOrg -Token $sourceToken -ProjectId $sourceProjectMeta.id -IncludeCapabilities -ApiVersion $apiVersion
        
        $processResult = Invoke-ADOProcessMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken `
            -SourceProject $sourceProject -ApiVersion $apiVersion
        
        $processResult.TargetProcess | Select-Object name,typeId
        # Ensures the inherited process exists (creates if missing) and returns Source/Target/Parent process objects.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOProcessMigration {
    [CmdletBinding()] 
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][pscustomobject]$SourceProject,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    Write-PSFMessage -Level Host -Message "Resolving source process for project '$($SourceProject.name)'."
    $sourceProcess = Get-ADOProcess -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessTypeId "$($SourceProject.capabilities.processTemplate.templateTypeId)"
    $sourceParentProcess = Get-ADOProcess -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessTypeId "$($sourceProcess.parentProcessTypeId)"

    Write-PSFMessage -Level Host -Message "Source project process: '$($sourceProcess.name)' (ID: $($sourceProcess.typeId))."
    Convert-FSCPSTextToAscii -Text "Migrate processes.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Checking if target process '$($sourceProcess.name)' exists in target organization '$TargetOrganization'."
    $targetProcess = (Get-ADOProcessList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion).Where({$_.name -eq $sourceProcess.name})

    if (-not $targetProcess) {
        Write-PSFMessage -Level Host -Message "Target process '$($sourceProcess.name)' does not exist. Creating it in target organization '$TargetOrganization'."
        $body = @{ name = $sourceProcess.name; parentProcessTypeId = $sourceParentProcess.typeId; description = $sourceProcess.description; customizationType = $sourceProcess.customizationType; isEnabled = 'true' } | ConvertTo-Json -Depth 10
        Write-PSFMessage -Level Verbose -Message "Adding process '$($sourceProcess.name)' to target organization '$TargetOrganization' with body: $body"
        $targetProcess = Add-ADOProcess -Organization $TargetOrganization -Token $TargetToken -Body $body -ApiVersion $ApiVersion
    } else {
        Write-PSFMessage -Level Host -Message "Target process '$($sourceProcess.name)' already exists in target organization '$TargetOrganization'."
    }

    return @{ SourceProcess = $sourceProcess; TargetProcess = $targetProcess; SourceParentProcess = $sourceParentProcess }
}