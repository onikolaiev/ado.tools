<#
    .SYNOPSIS
        Retrieves a list of all work item types in a process.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and retrieve all work item types in a process.
        It supports optional parameters to expand specific properties of the work item types.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessId
        The ID of the process.

    .PARAMETER Expand
        Optional parameter to expand specific properties of the work item types (e.g., behaviors, layout, states).

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        Get-ADOWorkItemTypeList -Organization "fabrikam" -Token "my-token" -ProcessId "c5ef8a1b-4f0d-48ce-96c4-20e62993c218"

        Retrieves all work item types in the specified process.

    .EXAMPLE
        Get-ADOWorkItemTypeList -Organization "fabrikam" -Token "my-token" -ProcessId "c5ef8a1b-4f0d-48ce-96c4-20e62993c218" -Expand "states"

        Retrieves all work item types in the specified process with the states property expanded.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Get-ADOWorkItemTypeList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProcessId,

        [Parameter()]
        [ValidateSet("behaviors", "layout", "states", "none")]
        [string]$Expand = $null,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting retrieval of work item types for ProcessId: $ProcessId in Organization: $Organization"
    }

    process {
        try {
            # Build the API URI with optional parameters
            $apiUri = "_apis/work/processes/$ProcessId" + "/workitemtypes?"
            if ($Expand) {
                $apiUri += "`$expand=$Expand&"
            }

            # Remove trailing '&' or '?' if present
            $apiUri = $apiUri.TrimEnd('&', '?')

            # Log the API URI
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "GET" `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully retrieved work item types for ProcessId: $ProcessId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.WorkItemTypeObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to retrieve work item types: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieval of work item types for ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}