<#
    .SYNOPSIS
        Removes a group from the work item form.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and remove a group from a specified section on a page in a work item type.

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
        The ID of the section the group is in.

    .PARAMETER GroupId
        The ID of the group to remove.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        Remove-ADOWorkItemTypeGroup -Organization "fabrikam" -Token "my-token" -ProcessId "906c7065-2a04-4f61-aac1-b5da9cef040b" -WitRefName "MyNewAgileProcess.ChangeRequest" -PageId "page-id" -SectionId "section-id" -GroupId "group-id"

        Removes the specified group from the section on the page.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Remove-ADOWorkItemTypeGroup {
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

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting removal of group '$GroupId' from section '$SectionId' on page '$PageId' for work item type '$WitRefName' in ProcessId: $ProcessId for Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/$ProcessId/workItemTypes/$WitRefName/layout/pages/$PageId/sections/$SectionId/groups/$GroupId"

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
            Write-PSFMessage -Level Host -Message "Successfully removed group '$GroupId' from section '$SectionId' on page '$PageId' for work item type '$WitRefName' in ProcessId: $ProcessId"
            return 
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to remove group: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed removal of group '$GroupId' from section '$SectionId' on page '$PageId' for work item type '$WitRefName' in ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}