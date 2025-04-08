<#
    .SYNOPSIS
        Updates a picklist.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and update a picklist by its ID.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ListId
        The ID of the picklist to update.

    .PARAMETER Body
        The JSON string containing the properties for the picklist to update.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        $body = @"
        {
            "id": "a07a079a-c79e-4221-9436-a9d732a8a4d0",
            "name": null,
            "type": null,
            "items": [
                "Blue",
                "Red"
            ],
            "isSuggested": false,
            "url": null
        }
        "@

        Update-ADOPickList -Organization "fabrikam" -Token "my-token" -ListId "a07a079a-c79e-4221-9436-a9d732a8a4d0" -Body $body

        Updates the specified picklist by its ID.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Update-ADOPickList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ListId,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting update of picklist with ID '$ListId' for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/lists/$ListId"

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"
            Write-PSFMessage -Level Verbose -Message "Request Body: $Body"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "PUT" `
                                             -Body $Body `
                                             -Headers @{"Content-Type" = "application/json"} `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully updated picklist with ID '$ListId' for Organization: $Organization"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.PickListObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to update picklist: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed update of picklist with ID '$ListId' for Organization: $Organization"
        Invoke-TimeSignal -End
    }
}