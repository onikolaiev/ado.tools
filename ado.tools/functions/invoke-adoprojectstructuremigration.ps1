
<#
    .SYNOPSIS
        Ensures target project exists (create/update).
    .DESCRIPTION
        Checks if the target project exists in the target organization. If not, it creates it using the source project's settings and the target process. If it exists, it updates the project to match the source project's description and process.
    .OUTPUTS
        The created or updated target project object.
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
    .PARAMETER TargetProcess
        The target process object containing details about the process to migrate to.
    .PARAMETER TargetProjectName
        The name of the target project to create or update.
    .PARAMETER SourceVersionControlCapabilities
        The source version control capabilities object containing details about the version control settings to migrate.
    .PARAMETER ApiVersion
    .EXAMPLE
        $apiVersion = '7.1'
        $sourceOrg  = 'srcOrg'
        $targetOrg  = 'tgtOrg'
        $sourceToken = 'pat-src'
        $targetToken = 'pat-tgt'
        $sourceProjectName = 'Sample'
        $targetProjectName = 'MigratedProject'
        $sourceProjectMeta = (Get-ADOProjectList -Organization $sourceOrg -Token $sourceToken -ApiVersion $apiVersion -StateFilter All) | Where-Object name -eq $sourceProjectName
        $sourceProject = Get-ADOProject -Organization $sourceOrg -Token $sourceToken -ProjectId $sourceProjectMeta.id -IncludeCapabilities -ApiVersion $apiVersion
        $proc = Invoke-ADOProcessMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg -SourceToken $sourceToken -TargetToken $targetToken -SourceProject $sourceProject -ApiVersion $apiVersion
        
        Invoke-ADOProjectStructureMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken -SourceProject $sourceProject -TargetProcess $proc.TargetProcess `
            -TargetProjectName $targetProjectName -SourceVersionControlCapabilities $sourceProject.capabilities.versioncontrol -ApiVersion $apiVersion
        # Creates or updates the target project aligned to target process.
        The version of the Azure DevOps REST API to use.
#>
function Invoke-ADOProjectStructureMigration {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][pscustomobject]$SourceProject,
        [Parameter(Mandatory)][pscustomobject]$TargetProcess,
        [Parameter(Mandatory)][string]$TargetProjectName,
        [Parameter(Mandatory)][pscustomobject]$SourceVersionControlCapabilities,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    Convert-FSCPSTextToAscii -Text "Migrate project.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Checking if target project '$TargetProjectName' exists in '$TargetOrganization'."
    $targetProject = (Get-ADOProjectList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -StateFilter All).Where({$_.name -eq $TargetProjectName})
    $body = @{ name=$TargetProjectName; description=$SourceProject.description; visibility=$SourceProject.visibility; capabilities=@{ versioncontrol=@{ sourceControlType=$SourceVersionControlCapabilities.sourceControlType }; processTemplate=@{ templateTypeId=$TargetProcess.typeId } } } | ConvertTo-Json -Depth 10
    if (-not $targetProject) {
        Write-PSFMessage -Level Host -Message "Creating project '$TargetProjectName'."
        $targetProject = Add-ADOProject -Organization $TargetOrganization -Token $TargetToken -Body $body -ApiVersion $ApiVersion
    } else {
        Write-PSFMessage -Level Host -Message "Updating project '$TargetProjectName'."
        $targetProject = Update-ADOProject -Organization $TargetOrganization -Token $TargetToken -Body $body -ProjectId $targetProject.id -ApiVersion $ApiVersion
    }
    return $targetProject
}