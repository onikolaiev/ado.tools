<#
    .SYNOPSIS
        Moves a control to a specified group.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and move a control to a new group in a specified work item type.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessId
        The ID of the process.

    .PARAMETER WitRefName
        The reference name of the work item type.

    .PARAMETER GroupId
        The ID of the group to move the control to.

    .PARAMETER ControlId
        The ID of the control to move.

    .PARAMETER Body
        The JSON string containing the properties for the control to move.

    .PARAMETER RemoveFromGroupId
        Optional parameter specifying the group ID to remove the control from.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        $body = @"
        {
            "label": "",
            "readonly": false,
            "id": "c1681eea-cf9e-4a32-aee9-83e97fde894a",
            "isContribution": true,
            "visible": true,
            "contribution": {
                "contributionId": "ms-devlabs.toggle-control.toggle-control-contribution",
                "inputs": {
                    "FieldName": "System.BoardColumnDone",
                    "TrueLabel": "new value"
                }
            },
            "order": 0
        }
        "@

        Move-ADOWorkItemTypeGroupControl -Organization "fabrikam" -Token "my-token" -ProcessId "906c7065-2a04-4f61-aac1-b5da9cef040b" -WitRefName "MyNewAgileProcess.ChangeRequest" -GroupId "new-group-id" -ControlId "control-id" -Body $body -RemoveFromGroupId "old-group-id"

        Moves the specified control to a new group.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Move-ADOWorkItemTypeGroupControl {
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
        [string]$GroupId,

        [Parameter(Mandatory = $true)]
        [string]$ControlId,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter()]
        [string]$RemoveFromGroupId = $null,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting move of control '$ControlId' to group '$GroupId' for work item type '$WitRefName' in ProcessId: $ProcessId for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI with optional parameters
            $apiUri = "_apis/work/processes/$ProcessId/workItemTypes/$WitRefName/layout/groups/$GroupId/controls/$ControlId?"
            if ($RemoveFromGroupId) {
                $apiUri += "removeFromGroupId=$RemoveFromGroupId&"
            }

            # Remove trailing '&' or '?' if present
            $apiUri = $apiUri.TrimEnd('&', '?')

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
            Write-PSFMessage -Level Host -Message "Successfully moved control '$ControlId' to group '$GroupId' for work item type '$WitRefName' in ProcessId: $ProcessId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.WorkItemTypeGroupControlObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to move control: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed move of control '$ControlId' to group '$GroupId' for work item type '$WitRefName' in ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}