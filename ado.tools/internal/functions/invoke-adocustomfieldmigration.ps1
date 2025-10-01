
<#
    .SYNOPSIS
        Migrate custom work item fields from source to target organization.
    .DESCRIPTION
        This function migrates custom work item fields (those starting with 'Custom.') from a source organization to a target organization.
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
    .PARAMETER SourceToken
        The authentication token for accessing the source Azure DevOps organization.
    .PARAMETER TargetToken
        The authentication token for accessing the target Azure DevOps organization.
    .PARAMETER TargetProcessName
        The name of the target process in the target organization.
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use.
    .EXAMPLE
        $apiVersion = '7.1'
        $sourceOrg  = 'srcOrg'
        $targetOrg  = 'tgtOrg'
        $sourceToken = 'pat-src'
        $targetToken = 'pat-tgt'
        $sourceProjectName = 'Sample'
        
        # Obtain source project & process to derive target process name
        $sourceProjectMeta = (Get-ADOProjectList -Organization $sourceOrg -Token $sourceToken -ApiVersion $apiVersion -StateFilter All) | Where-Object name -eq $sourceProjectName
        $sourceProject = Get-ADOProject -Organization $sourceOrg -Token $sourceToken -ProjectId $sourceProjectMeta.id -IncludeCapabilities -ApiVersion $apiVersion
        $proc = Invoke-ADOProcessMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg -SourceToken $sourceToken -TargetToken $targetToken -SourceProject $sourceProject -ApiVersion $apiVersion
        $targetProcessName = $proc.TargetProcess.name
        
        Invoke-ADOCustomFieldMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg `
            -SourceToken $sourceToken -TargetToken $targetToken -TargetProcessName $targetProcessName -ApiVersion $apiVersion
        # Copies all Custom.* fields and ensures tracking field Custom.SourceWorkitemId exists.
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Invoke-ADOCustomFieldMigration {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$SourceOrganization,
        [Parameter(Mandatory)][string]$TargetOrganization,
        [Parameter(Mandatory)][string]$SourceToken,
        [Parameter(Mandatory)][string]$TargetToken,
        [Parameter(Mandatory)][string]$TargetProcessName,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    Convert-FSCPSTextToAscii -Text "Migrate wit fields.." -Font "Standard"
    Write-PSFMessage -Level Host -Message "Fetching custom work item fields from source organization '$SourceOrganization'."
    $sourceFields = (Get-ADOWitFieldList -Organization $SourceOrganization -Token $SourceToken -Expand 'extensionFields' -ApiVersion $ApiVersion).Where({$_.referenceName.StartsWith('Custom.')})
    Write-PSFMessage -Level Host -Message "Found $($sourceFields.Count) custom fields in source organization."

    Write-PSFMessage -Level Host -Message "Fetching custom work item fields from target organization '$TargetOrganization'."
    $targetFields = (Get-ADOWitFieldList -Organization $TargetOrganization -Token $TargetToken -Expand 'extensionFields' -ApiVersion $ApiVersion).Where({$_.referenceName.StartsWith('Custom.')})
    Write-PSFMessage -Level Host -Message "Found $($targetFields.Count) custom fields in target organization."

    foreach ($field in $sourceFields) {
        if (-not ($targetFields.Where({$_.name -eq $field.name}))) {
            Write-PSFMessage -Level Host -Message "Custom field '$($field.name)' does not exist in target organization. Adding it."
            $fullField = Get-ADOWitField -Organization $SourceOrganization -Token $SourceToken -FieldNameOrRefName $field.referenceName -ApiVersion $ApiVersion
            $body = @{ name=$fullField.name; referenceName=$fullField.referenceName; description=$fullField.description; type=$fullField.type; usage=$fullField.usage; readOnly=$fullField.readOnly; isPicklist=$fullField.isPicklist; isPicklistSuggested=$fullField.isPicklistSuggested; isIdentity=$fullField.isIdentity; isQueryable=$fullField.isQueryable; isLocked=$fullField.isLocked; canSortBy=$fullField.canSortBy; supportedOperations=$fullField.supportedOperations } | ConvertTo-Json -Depth 10
            Write-PSFMessage -Level Verbose -Message "Adding custom field '$($fullField.name)' to target process '$TargetProcessName' with body: $body"
            $null = Add-ADOWitField -Organization $TargetOrganization -Token $TargetToken -Body $body -ApiVersion $ApiVersion
        } else {
            Write-PSFMessage -Level Host -Message "Custom field '$($field.name)' already exists in target organization. Skipping."
        }
    }

    # Ensure SourceWorkitemId tracking field
    $trackingName = 'SourceWorkitemId'
    $trackingRef  = "Custom.$trackingName"
    if (-not ($targetFields.Where({$_.referenceName -eq $trackingRef}))) {
        $body = @{ name=$trackingName; referenceName=$trackingRef; description=''; type='string'; usage='workItem'; readOnly=$false; isQueryable=$true; isLocked=$false; canSortBy=$true } | ConvertTo-Json -Depth 10
        Write-PSFMessage -Level Verbose -Message "Ensuring tracking field '$trackingRef' in target organization."    
        Add-ADOWitField -Organization $TargetOrganization -Token $TargetToken -Body $body -ApiVersion $ApiVersion -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
    }
}