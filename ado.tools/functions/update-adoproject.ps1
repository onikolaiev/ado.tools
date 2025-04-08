
<#
    .SYNOPSIS
        Updates an existing Azure DevOps project.
        
    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and update an existing project's properties.
        It expects the request body as a JSON string parameter.
        
    .PARAMETER Organization
        The name of the Azure DevOps organization.
        
    .PARAMETER Token
        The authentication token for accessing Azure DevOps.
        
    .PARAMETER ProjectId
        The ID of the project to update.
        
    .PARAMETER Body
        The JSON string containing the properties to update for the project.
        
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use.
        
    .EXAMPLE
        $body = @"
        {
        "name": "New Project Name",
        "description": "Updated description",
        "visibility": "Private"
        }
        "@
        
        Update-ADOProject -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c" -Body $body
        
        Updates the specified project with the provided properties.
        
    .NOTES
        This function follows PSFramework best practices for logging and error handling.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Update-ADOProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting update for ProjectId: $ProjectId in Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/projects/$($ProjectId)"

            # Log the request body
            Write-PSFMessage -Level Verbose -Message "Request Body: $Body"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Headers @{"Content-Type" = "application/json"} `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method Patch `
                                             -Body $Body `
                                             -ApiVersion $ApiVersion

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully updated project with ProjectId: $ProjectId"
            return $response
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to update project: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed update for ProjectId: $ProjectId"
        Invoke-TimeSignal -End
    }
}