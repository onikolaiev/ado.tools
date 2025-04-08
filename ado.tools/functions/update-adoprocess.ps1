<#
    .SYNOPSIS
        Edits a process by its ID.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and update a specific process by its ID.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessTypeId
        The ID of the process to edit.

    .PARAMETER Body
        The JSON string containing the properties to update for the process.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        $body = @"
        {
            "name": "MyNewAgileProcess_Renamed",
            "description": "My new renamed process",
            "isDefault": false,
            "isEnabled": false
        }
        "@

        Update-ADOProcess -Organization "fabrikam" -Token "my-token" -ProcessTypeId "fb70612d-c6d5-421a-ace1-04939e81b669" -Body $body

        Updates the specified process by its ID.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Update-ADOProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProcessTypeId,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting update of process with ID '$ProcessTypeId' for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/$ProcessTypeId"

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"
            Write-PSFMessage -Level Verbose -Message "Request Body: $Body"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "PATCH" `
                                             -Body $Body `
                                             -Headers @{"Content-Type" = "application/json"} `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully updated process with ID '$ProcessTypeId' for Organization: $Organization"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.ProcessObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to update process: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed update of process with ID '$ProcessTypeId' for Organization: $Organization"
        Invoke-TimeSignal -End
    }
}