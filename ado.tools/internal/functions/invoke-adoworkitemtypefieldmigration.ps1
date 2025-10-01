
<#
    .SYNOPSIS
        Migrates custom fields assigned to each inherited WIT in process.
    .DESCRIPTION
        This function migrates custom fields assigned to each inherited work item type (WIT) in
        a process from a source Azure DevOps organization to a target Azure DevOps organization.
        It ensures that all custom fields are copied over to the target WITs, preserving any
        customizations made in the source process.
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
        
        Invoke-ADOWorkItemTypeFieldMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess `
            -SourceWitList $witResult.SourceList -TargetWitList $witResult.TargetList -ApiVersion $apiVersion
        # Copies non-system custom field assignments for each inherited WIT.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
        
#>
function Invoke-ADOWorkItemTypeFieldMigration {
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
    Convert-FSCPSTextToAscii -Text "Migrate fields.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Starting to process custom fields for work item types."
    foreach ($wit in $SourceWitList) {
        Write-PSFMessage -Level Host -Message "Processing fields for work item type '$($wit.name)'."
        $targetWit = $TargetWitList.Where({$_.name -eq $wit.name})
        if (-not $targetWit) { continue }
        $customFields = (Get-ADOWorkItemTypeFieldList -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName).Where({$_.customization -ne 'system'})
        foreach ($field in $customFields) {
            Write-PSFMessage -Level Host -Message "Checking field '$($field.name)' in target process."
            $targetField = (Get-ADOWorkItemTypeFieldList -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName).Where({$_.name -eq $field.name})
            if (-not $targetField) {
                Write-PSFMessage -Level Host -Message "Field '$($field.name)' does not exist in target process. Adding it."
                $srcField = Get-ADOWorkItemTypeField -Organization $SourceOrganization -Token $SourceToken -ApiVersion $ApiVersion -ProcessId $SourceProcess.typeId -WitRefName $wit.referenceName -FieldRefName $field.referenceName -Expand all
                $body = @{ allowGroups=$srcField.allowGroups; allowedValues=$srcField.allowedValues; description=$srcField.description; defaultValue=$srcField.defaultValue; readOnly=$srcField.readOnly; referenceName=$srcField.referenceName; required=$srcField.required } | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Verbose -Message "Adding field '$($srcField.name)' to target process '$($TargetProcess.name)' with body: $body"
                $null = Add-ADOWorkItemTypeField -Organization $TargetOrganization -Token $TargetToken -ApiVersion $ApiVersion -ProcessId $TargetProcess.typeId -WitRefName $targetWit.referenceName -Body $body
            } else {
                Write-PSFMessage -Level Host -Message "Field '$($field.name)' already exists in target process. Skipping."
            }
        }
    }
}