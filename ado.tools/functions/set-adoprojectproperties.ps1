<#
    .SYNOPSIS
        Create, update, or delete team project properties in Azure DevOps.

    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and perform operations on team project properties.
        It supports operations such as add, remove, replace, and more using JSON Patch.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER Token
        The authentication token for accessing Azure DevOps.

    .PARAMETER ProjectId
        The ID of the project to update properties for.

    .PARAMETER Body
        The JSON Patch document as a string, specifying the operations to perform on the project properties.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1-preview.1".

    .EXAMPLE
        $body = @"
        [
            {
                "op": "add",
                "path": "/Alias",
                "value": "Fabrikam"
            }
        ]
        "@

        Set-ADOProjectProperties -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c" -Body $body

        Creates or updates the "Alias" property for the specified project.

    .EXAMPLE
        $body = @"
        [
            {
                "op": "remove",
                "path": "/Alias"
            }
        ]
        "@

        Set-ADOProjectProperties -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c" -Body $body

        Deletes the "Alias" property for the specified project.

    .NOTES
        This function follows PSFramework best practices for logging and error handling.

        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Set-ADOProjectProperties {
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
        Write-PSFMessage -Level Verbose -Message "Starting update of project properties for ProjectId: $ProjectId in Organization: $Organization"
    }

    process {
        try {
            # Build the API URI
            $apiUri = "_apis/projects/$ProjectId/properties"

            # Log the request details
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"
            Write-PSFMessage -Level Verbose -Message "Request Body: $Body"

            # Call the Invoke-ADOApiRequest function
            $null = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method "PATCH" `
                                             -Body $Body `
                                             -ApiVersion $ApiVersion `
                                             -Headers @{ "Content-Type" = "application/json-patch+json" }

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully updated project properties for ProjectId: $ProjectId"
            return 
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to update project properties: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed update of project properties for ProjectId: $ProjectId"
        Invoke-TimeSignal -End
    }
}