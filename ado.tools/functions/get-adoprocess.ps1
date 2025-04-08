<#
    .SYNOPSIS
        Retrieves a single process by its ID.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and retrieve a specific process by its ID.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessTypeId
        The ID of the process to retrieve.

    .PARAMETER Expand
        Optional parameter to expand specific properties of the process (e.g., projects, none).

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        Get-ADOProcess -Organization "fabrikam" -Token "my-token" -ProcessTypeId "adcc42ab-9882-485e-a3ed-7678f01f66bc"

        Retrieves the specified process by its ID.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Get-ADOProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProcessTypeId,

        [Parameter()]
        [ValidateSet("projects", "none")]
        [string]$Expand = $null,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting retrieval of process with ID '$ProcessTypeId' for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI with optional parameters
            $apiUri = "_apis/work/processes/$ProcessTypeId?"
            if ($Expand) {
                $apiUri += "`$expand=$Expand&"
            }

            # Remove trailing '&' or '?' if present
            $apiUri = $apiUri.TrimEnd('&', '?')

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "GET" `
                                             -Headers @{"Content-Type" = "application/json"} `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully retrieved process with ID '$ProcessTypeId' for Organization: $Organization"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.ProcessObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to retrieve process: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieval of process with ID '$ProcessTypeId' for Organization: $Organization"
        Invoke-TimeSignal -End
    }
}