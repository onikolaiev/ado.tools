
<#
    .SYNOPSIS
        Retrieves a list of projects in the Azure DevOps organization that the authenticated user has access to.
        
    .DESCRIPTION
        This function uses the `Invoke-ADOApiRequest` function to call the Azure DevOps REST API and retrieve a list of projects.
        It supports optional parameters such as state filter, pagination, and default team image URL.
        
    .PARAMETER Organization
        The name of the Azure DevOps organization.
        
    .PARAMETER Token
        The authentication token for accessing Azure DevOps.
        
    .PARAMETER StateFilter
        Filter on team projects in a specific state (e.g., WellFormed, Deleted, All). Default is WellFormed.
        
    .PARAMETER Top
        The maximum number of projects to return.
        
    .PARAMETER Skip
        The number of projects to skip.
        
    .PARAMETER ContinuationToken
        Pointer that shows how many projects have already been fetched.
        
    .PARAMETER GetDefaultTeamImageUrl
        Whether to include the default team image URL in the response.
        
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is set globally.
        
    .EXAMPLE
        Get-ADOProjectList -Organization "fabrikam" -Token "my-token"
        
        Retrieves all projects in the specified organization.
        
    .EXAMPLE
        Get-ADOProjectList -Organization "fabrikam" -Token "my-token" -StateFilter "WellFormed" -Top 10
        
        Retrieves the first 10 well-formed projects in the specified organization.
        
    .NOTES
        The function will return the project list in a structured format.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>
function Get-ADOProjectList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter()]
        [ProjectState]$StateFilter = [ProjectState]::All,

        [Parameter()]
        [int]$Top = $null,

        [Parameter()]
        [int]$Skip = $null,

        [Parameter()]
        [int]$ContinuationToken = $null,

        [Parameter()]
        [switch]$GetDefaultTeamImageUrl,

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        Invoke-TimeSignal -Start        
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Building API URI for retrieving project list."
    }

    process {
        try {
            # Build the API URI with optional parameters
            $apiUri = "_apis/projects?"
            if ($StateFilter) {
                $apiUri += "stateFilter=$StateFilter&"
            }
            if ($Top) {
                $apiUri += "`$top=$Top&"
            }
            if ($Skip) {
                $apiUri += "`$skip=$Skip&"
            }
            if ($ContinuationToken) {
                $apiUri += "continuationToken=$ContinuationToken&"
            }
            if ($GetDefaultTeamImageUrl) {
                $apiUri += "getDefaultTeamImageUrl=$GetDefaultTeamImageUrl&"
            }

            # Remove trailing '&' or '?' if present
            $apiUri = $apiUri.TrimEnd('&', '?')

            # Determine if OnlyFirstPage should be passed
            $onlyFirstPage = $Top -ne $null

            # Log the API URI
            Write-PSFMessage -Level Verbose -Message "API URI: $apiUri"

            # Call the Invoke-ADOApiRequest function
            if ($onlyFirstPage) {
                Write-PSFMessage -Level Verbose -Message "Fetching only the first page of results."
                $response = Invoke-ADOApiRequest -Organization $Organization `
                                                 -Token $Token `
                                                 -Method GET `
                                                 -ApiUri $apiUri `
                                                 -ApiVersion $ApiVersion `
                                                 -OnlyFirstPage
            } else {
                Write-PSFMessage -Level Verbose -Message "Fetching all results."
                $response = Invoke-ADOApiRequest -Organization $Organization `
                                                 -Token $Token `
                                                 -ApiVersion $ApiVersion `
                                                 -Method GET `
                                                 -ApiUri $apiUri
            }

            # Log the successful response
            Write-PSFMessage -Level Host -Message "Successfully retrieved project list."
            return $response.Results
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to retrieve project list: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieving project list."
        Invoke-TimeSignal -End
    }
}