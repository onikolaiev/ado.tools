
<#
    .SYNOPSIS
        Retrieves a collection of team project properties in Azure DevOps.
        
    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and retrieve properties of a specific project.
        It supports optional parameters to filter properties by specific keys.
        
    .PARAMETER Organization
        The name of the Azure DevOps organization.
        
    .PARAMETER Token
        The authentication token for accessing Azure DevOps.
        
    .PARAMETER ProjectId
        The ID of the project to retrieve properties for.
        
    .PARAMETER Keys
        A comma-delimited string of team project property names to filter the results. Wildcard characters ("?" and "*") are supported.
        If no key is specified, all properties will be returned.

    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is set globally.
        
    .EXAMPLE
        Get-ADOProjectProperties -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c"
        
        Retrieves all properties for the specified project.
        
    .EXAMPLE
        Get-ADOProjectProperties -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c" -Keys "System.CurrentProcessTemplateId,*SourceControl*"
        
        Retrieves specific properties for the specified project.
        
    .NOTES
        This function follows PSFramework best practices for logging and error handling.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Get-ADOProjectProperties {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [Parameter()]
        [string]$Keys = $null,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting retrieval of project properties for ProjectId: $ProjectId in Organization: $Organization"
    }

    process {
        try {
            # Build the API URI with optional parameters
            $apiUri = "_apis/projects/$ProjectId/properties?"
            if ($Keys) {
                $apiUri += "keys=$Keys&"
            }

            # Remove trailing '&' or '?' if present
            $apiUri = $apiUri.TrimEnd('&', '?')

            # Log the API URI
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            $response = Invoke-ADOApiRequest -Organization $Organization `
                                             -Token $Token `
                                             -ApiUri $apiUri `
                                             -ApiVersion $ApiVersion
            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully retrieved project properties for ProjectId: $ProjectId"
            return $response.Results | Select-PSFObject * -TypeName "ADO.TOOLS.ProjectProperty" 
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to retrieve project properties: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieval of project properties for ProjectId: $ProjectId"
        Invoke-TimeSignal -End
    }
}