<#
    .SYNOPSIS
        Creates a picklist.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and create a new picklist in the specified organization.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER Body
        The JSON string containing the properties for the picklist to create.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        $body = @"
        {
            "id": null,
            "name": "picklist_aef2c045-0d2d-4f92-9d09-56eea553e1ef",
            "type": "String",
            "url": null,
            "items": [
                "Blue",
                "Green",
                "Red"
            ],
            "isSuggested": false
        }
        "@

        Add-ADOPickList -Organization "fabrikam" -Token "my-token" -Body $body

        Creates a new picklist in the specified organization.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Add-ADOPickList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting creation of a new picklist for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/lists"

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"
            Write-PSFMessage -Level Verbose -Message "Request Body: $Body"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "POST" `
                                             -Body $Body `
                                             -Headers @{"Content-Type" = "application/json"} `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully created a new picklist for Organization: $Organization"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.PickListObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to create picklist: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed creation of a new picklist for Organization: $Organization"
        Invoke-TimeSignal -End
    }
}