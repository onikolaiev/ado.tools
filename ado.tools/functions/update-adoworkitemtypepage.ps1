<#
    .SYNOPSIS
        Updates a page on the work item form.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and update a page in the layout of a specified work item type.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessId
        The ID of the process where the work item type exists.

    .PARAMETER WitRefName
        The reference name of the work item type.

    .PARAMETER Body
        The JSON string containing the properties for the page to update.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        $body = @"
        {
            "sections": null,
            "id": "230f8598-71ed-4192-917e-aa1aacc5174a",
            "label": "Page2",
            "overridden": null,
            "inherited": null,
            "visible": true,
            "locked": false,
            "pageType": "custom",
            "contribution": null
        }
        "@

        Update-ADOWorkItemTypePage -Organization "fabrikam" -Token "my-token" -ProcessId "c5ef8a1b-4f0d-48ce-96c4-20e62993c218" -WitRefName "MyNewAgileProcess.ChangeRequest" -Body $body

        Updates the specified page in the work item type.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Update-ADOWorkItemTypePage {
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
        [string]$Body,

        [Parameter()]
        [string]$ApiVersion = "7.1"
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting update of a page in work item type '$WitRefName' in ProcessId: $ProcessId for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/$ProcessId/workItemTypes/$WitRefName/layout/pages"

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
            Write-PSFMessage -Level Host -Message "Successfully updated a page in work item type '$WitRefName' in ProcessId: $ProcessId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.WorkItemTypePageObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to update a page: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed update of a page in work item type '$WitRefName' in ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}