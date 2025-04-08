<#
    .SYNOPSIS
        Retrieves a behavior of the process.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and retrieve a specific behavior for a specified process.
        It supports optional parameters to expand specific properties of the behavior.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessId
        The ID of the process.

    .PARAMETER BehaviorRefName
        The reference name of the behavior.

    .PARAMETER Expand
        Optional parameter to expand specific properties of the behavior (e.g., fields, combinedFields, none).

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        Get-ADOProcessBehavior -Organization "fabrikam" -Token "my-token" -ProcessId "906c7065-2a04-4f61-aac1-b5da9cef040b" -BehaviorRefName "System.RequirementBacklogBehavior"

        Retrieves the specified behavior for the process.

    .EXAMPLE
        Get-ADOProcessBehavior -Organization "fabrikam" -Token "my-token" -ProcessId "906c7065-2a04-4f61-aac1-b5da9cef040b" -BehaviorRefName "System.RequirementBacklogBehavior" -Expand "fields"

        Retrieves the specified behavior for the process with fields expanded.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Get-ADOProcessBehavior {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProcessId,

        [Parameter(Mandatory = $true)]
        [string]$BehaviorRefName,

        [Parameter()]
        [ValidateSet("fields", "combinedFields", "none")]
        [string]$Expand = $null,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting retrieval of behavior '$BehaviorRefName' for ProcessId: $ProcessId in Organization: $Organization"
    }

    process {
        try {
            # Build the API URI with optional parameters
            $apiUri = "_apis/work/processes/$ProcessId/behaviors/$BehaviorRefName?"
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
                                             -Headers @{"Content-Type" = "application/json" } `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully retrieved behavior '$BehaviorRefName' for ProcessId: $ProcessId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.ProcessBehaviorObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to retrieve behavior: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieval of behavior '$BehaviorRefName' for ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}