<#
    .SYNOPSIS
        Removes a behavior in the process.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and remove a behavior from a specified process.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProcessId
        The ID of the process.

    .PARAMETER BehaviorRefName
        The reference name of the behavior to remove.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        Remove-ADOProcessBehavior -Organization "fabrikam" -Token "my-token" -ProcessId "906c7065-2a04-4f61-aac1-b5da9cef040b" -BehaviorRefName "Custom.891ef145-4c43-4151-a756-7a8b2d489ee5"

        Removes the specified behavior from the process.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Remove-ADOProcessBehavior {
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
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting removal of behavior '$BehaviorRefName' for ProcessId: $ProcessId in Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/work/processes/$ProcessId/behaviors/$BehaviorRefName"

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            $null = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "DELETE" `
                                             -Headers @{ "Content-Type" = "application/json"  } `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully removed behavior '$BehaviorRefName' for ProcessId: $ProcessId"
            return 
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to remove behavior: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed removal of behavior '$BehaviorRefName' for ProcessId: $ProcessId"
        Invoke-TimeSignal -End
    }
}