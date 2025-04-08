<#
    .SYNOPSIS
        Retrieves a single state definition in a work item type of the process.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and retrieve a single state definition for a specified work item type.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessId
        The ID of the process where the work item type exists.

    .PARAMETER WitRefName
        The reference name of the work item type.

    .PARAMETER StateId
        The ID of the state to retrieve.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        Get-ADOWorkItemTypeState -Organization "fabrikam" -Token "my-token" -ProcessId "c5ef8a1b-4f0d-48ce-96c4-20e62993c218" -WitRefName "MyNewAgileProcess.ChangeRequest" -StateId "7b7e3e8c-e500-40b6-ad56-d59b8d64d757"

        Retrieves the specified state definition for the work item type.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Get-ADOWorkItemTypeState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProcessId,

        [Parameter(Mandatory = $true)]
        [string]$WitRefName,

        [Parameter(Mandatory = $true)]
        [string]$StateId,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting retrieval of state '$StateId' for work item type '$WitRefName' in ProcessId: $ProcessId for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/$ProcessId/workItemTypes/$WitRefName/states/$StateId"

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "GET" `
                                             -Headers @{ "Content-Type" = "application/json" } `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully retrieved state '$StateId' for work item type '$WitRefName' in ProcessId: $ProcessId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.WorkItemTypeStateObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to retrieve state: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieval of state '$StateId' for work item type '$WitRefName' in ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}