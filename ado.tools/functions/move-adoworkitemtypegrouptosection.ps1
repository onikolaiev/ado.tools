<#
    .SYNOPSIS
        Moves a group to a different section.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and move a group to a new section in a specified work item type.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessId
        The ID of the process.

    .PARAMETER WitRefName
        The reference name of the work item type.

    .PARAMETER PageId
        The ID of the page the group is in.

    .PARAMETER SectionId
        The ID of the section to move the group to.

    .PARAMETER GroupId
        The ID of the group to move.

    .PARAMETER RemoveFromSectionId
        The ID of the section to remove the group from.

    .PARAMETER Body
        The JSON string containing the properties for the group to move.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        $body = @"
        {
            "id": "faf0f718-776c-422a-9424-3c5f7952901c",
            "label": "NewGroup1",
            "controls": null,
            "order": 1,
            "visible": true,
            "contribution": null,
            "isContribution": false,
            "height": null
        }
        "@

        Move-ADOWorkItemTypeGroupToSection -Organization "fabrikam" -Token "my-token" -ProcessId "906c7065-2a04-4f61-aac1-b5da9cef040b" -WitRefName "MyNewAgileProcess.ChangeRequest" -PageId "page-id" -SectionId "new-section-id" -GroupId "group-id" -RemoveFromSectionId "old-section-id" -Body $body

        Moves the specified group to a new section.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Move-ADOWorkItemTypeGroupToSection {
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
        [string]$PageId,

        [Parameter(Mandatory = $true)]
        [string]$SectionId,

        [Parameter(Mandatory = $true)]
        [string]$GroupId,

        [Parameter(Mandatory = $true)]
        [string]$RemoveFromSectionId,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting move of group '$GroupId' to section '$SectionId' on page '$PageId' for work item type '$WitRefName' in ProcessId: $ProcessId for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI with optional parameters
            $apiUri = "_apis/work/processes/$ProcessId/workItemTypes/$WitRefName/layout/pages/$PageId/sections/$SectionId/groups/$GroupId?"
            $apiUri += "removeFromSectionId=$RemoveFromSectionId"

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
            Write-PSFMessage -Level Host -Message "Successfully moved group '$GroupId' to section '$SectionId' on page '$PageId' for work item type '$WitRefName' in ProcessId: $ProcessId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.WorkItemTypeGroupObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to move group: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed move of group '$GroupId' to section '$SectionId' on page '$PageId' for work item type '$WitRefName' in ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}