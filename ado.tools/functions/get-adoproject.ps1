
<#
    .SYNOPSIS
        Retrieves a specific project in the Azure DevOps organization by its ID or name.
        
    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and retrieve a specific project.
        It supports optional parameters to include capabilities and history in the response.
        
    .PARAMETER Organization
        The name of the Azure DevOps organization.
        
    .PARAMETER Token
        The authentication token for accessing Azure DevOps.
        
    .PARAMETER ProjectId
        The ID or name of the project to retrieve.
        
    .PARAMETER IncludeCapabilities
        Whether to include capabilities (such as source control) in the team project result. Default is $false.
        
    .PARAMETER IncludeHistory
        Whether to search within renamed projects (that had such name in the past). Default is $false.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is set globally.
        
    .EXAMPLE
        Get-ADOProject -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c"
        
        Retrieves the project with the specified ID.
        
    .EXAMPLE
        Get-ADOProject -Organization "fabrikam" -Token "my-token" -ProjectId "MyProject" -IncludeCapabilities -IncludeHistory
        
        Retrieves the project with the specified name, including capabilities and history.
        
    .NOTES
        The project ID can be either the GUID or the name of the project.
        The function will return the project details in a structured format.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Get-ADOProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [Parameter()]
        [switch]$IncludeCapabilities,

        [Parameter()]
        [switch]$IncludeHistory,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting retrieval of project details for ProjectId: $ProjectId in Organization: $Organization"
        $apiUri = "_apis/projects/$($ProjectId)?"
        if ($IncludeCapabilities) {
            $apiUri += "includeCapabilities=$IncludeCapabilities&"
        }
        if ($IncludeHistory) {
            $apiUri += "includeHistory=$IncludeHistory&"
        }

        # Remove trailing '&' or '?' if present
        $apiUri = $apiUri.TrimEnd('&', '?')
    }

    process {
        try {
            # Build the API URI with optional parameters


            # Log the API URI
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -Method GET `
                                             -ApiVersion $ApiVersion 

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully retrieved project details for ProjectId: $ProjectId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.ProjectObject"
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to retrieve project details: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieval of project details for ProjectId: $ProjectId"
        Invoke-TimeSignal -End
    }
}