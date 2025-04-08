
<#
    .SYNOPSIS
        Queues a project to be deleted in Azure DevOps.
        
    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and queue a project for deletion.
        Use the `GetOperation` API to periodically check the status of the delete operation.
        
    .PARAMETER Organization
        The name of the Azure DevOps organization.
        
    .PARAMETER Token
        The authentication token for accessing Azure DevOps.
        
    .PARAMETER ProjectId
        The ID of the project to delete.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is set globally.
        
    .EXAMPLE
        Remove-ADOProject -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c"
        
        Queues the project with the specified ID for deletion.
        
    .NOTES
        This function requires the `Invoke-ADOApiRequest` function to be defined.
        It follows PSFramework best practices for logging and error handling.
#>
function Remove-ADOProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting project deletion for ProjectId: $ProjectId in Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/projects/$ProjectId"

            # Call the Invoke-ADOApiRequest function to queue the project for deletion
            $null = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "DELETE" `
                                             -Headers @{"Content-Type" = "application/json"} `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Project deletion queued successfully. Operation ID: $($response.id)"
            return 
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to queue project deletion: $($_.ErrorDetails.Message)"  -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed project deletion request for ProjectId: $ProjectId"
        Invoke-TimeSignal -End
    }
}