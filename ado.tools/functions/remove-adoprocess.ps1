<#
    .SYNOPSIS
        Removes a process by its ID.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and delete a specific process by its ID.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessTypeId
        The ID of the process to delete.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        Remove-ADOProcess -Organization "fabrikam" -Token "my-token" -ProcessTypeId "adcc42ab-9882-485e-a3ed-7678f01f66bc"

        Deletes the specified process by its ID.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Remove-ADOProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProcessTypeId,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting removal of process with ID '$ProcessTypeId' for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/$ProcessTypeId"

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            $null = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "DELETE" `
                                             -Headers @{"Content-Type" = "application/json"} `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully removed process with ID '$ProcessTypeId' for Organization: $Organization"
            return 
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to remove process: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed removal of process with ID '$ProcessTypeId' for Organization: $Organization"
        Invoke-TimeSignal -End
    }
}