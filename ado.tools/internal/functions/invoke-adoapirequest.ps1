
<#
    .SYNOPSIS
        A universal function to interact with Azure DevOps REST API endpoints.
        
    .DESCRIPTION
        The `Invoke-ADOApiRequest` function allows interaction with any Azure DevOps REST API endpoint.
        It requires the organization, a valid authentication token, and the specific API URI.
        The project is optional and will only be included in the URL if specified.
        
    .PARAMETER Organization
        The name of the Azure DevOps organization.
        
    .PARAMETER Project
        The name of the Azure DevOps project (optional).
        
    .PARAMETER Token
        The authentication token for accessing Azure DevOps.
        
    .PARAMETER ApiUri
        The specific Azure DevOps REST API URI to interact with (relative to the organization or project URL).
        
    .PARAMETER Method
        The HTTP method to use for the request (e.g., GET, POST, PUT, DELETE). Default is "GET".
        
    .PARAMETER Body
        The body content to include in the HTTP request (for POST/PUT requests).
        
    .PARAMETER Headers
        Additional headers to include in the request.
        
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".
        
    .PARAMETER OnlyFirstPage
        If enabled, the function will return only the first page of results and stop if a continuation token is present.
        
    .EXAMPLE
        Invoke-ADOApiRequest -Organization "my-org" -ApiUri "_apis/testplan/Plans/123/suites" -Token "my-token"
        
        This example retrieves test suites from the test plan with ID 123 in the specified organization.
        
    .EXAMPLE
        Invoke-ADOApiRequest -Organization "my-org" -ApiUri "_apis/projects" -Token "my-token" -OnlyFirstPage
        
        This example retrieves only the first page of projects in the specified organization.
        
    .NOTES
        - The function uses the Azure DevOps REST API.
        - An authentication token is required.
        - Handles pagination through continuation tokens.
#>

function Invoke-ADOApiRequest {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter()]
        [string]$Project = $null,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$ApiUri,

        [Parameter()]
        [ValidateSet("GET", "POST", "PUT", "DELETE", "PATCH")]
        [string]$Method = "GET",

        [Parameter()]
        [string]$Body = $null,

        [Parameter()]
        [Hashtable]$Headers = @{}, 

        [Parameter()]
        [string]$ApiVersion = $Script:ADOApiVersion,

        [Parameter()]
        [switch]$OnlyFirstPage
    )
    begin {
        Invoke-TimeSignal -Start
        if (-not $Token) {
            Write-PSFMessage -Level Error -Message "Token is required"
            return
        }
        if (-not $ApiUri) {
            Write-PSFMessage -Level Error -Message "ApiUri is required"
            return
        }
        if (-not $Organization) {
            Write-PSFMessage -Level Error -Message "Organization is required"
            return
        }
        if ($Organization.StartsWith("https://dev.azure.com") -eq $false) {
            $Organization = "https://dev.azure.com/$Organization"
        }

        # Prepare Authorization Header
        if ($Token.StartsWith("Bearer")) {
            $authHeader = @{ Authorization = "$Token"}
        } else {
            $authHeader = @{ Authorization = "Bearer $Token" }
        }

        # Merge additional headers
        $headers = $authHeader + $Headers

        $allResults = @()
        $continuationToken = $null
        $requestUrl = ""
    }
    process {       

        try {
            $statusCode = $null

            do {
                # Construct the full URL with API version and continuation token
                $baseUrl = if ($Project) { "$Organization/$Project" } else { $Organization }
                $baseUrl = $baseUrl.TrimEnd('/')
                $ApiUri = $ApiUri.TrimStart('/').TrimEnd('/')                
                $requestUrl = "$baseUrl/$ApiUri"   
                
                if ($continuationToken) {
                    $requestUrl += "&continuationToken=$continuationToken"
                }
                
                $requestUrl = if ($requestUrl.Contains("?")) 
                { [System.Uri]::EscapeUriString("$requestUrl" + "&api-version=$ApiVersion") } 
                else 
                { [System.Uri]::EscapeUriString("$requestUrl" + "?api-version=$ApiVersion") }

                Write-PSFMessage -Level Host -Message "Request URL: $Method $requestUrl"

                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    $response = Invoke-RestMethod -Uri $requestUrl -Headers $headers -Method $Method.ToLower() -Body $Body -ResponseHeadersVariable responseHeaders -StatusCodeVariable statusCode
                    $continuationToken = $responseHeaders['x-ms-continuationtoken']
                } else {
                    $response = Invoke-WebRequest -Uri $requestUrl -Headers $headers -Method $Method.ToLower() -Body $Body -UseBasicParsing
                    $continuationToken = $response.Headers['x-ms-continuationtoken']
                    $statusCode = $response.StatusCode
                    $response = $response.Content | ConvertFrom-Json
                }
                
                if ($statusCode -in @(200, 201, 202, 204 )) {
                    if ($response.value) {
                        $allResults += $response.value
                    } else {
                        $allResults += $response
                    }

                    # If OnlyFirstPage is enabled, stop after the first response
                    if ($OnlyFirstPage -and $continuationToken) {
                        break
                    }
                } else {
                    Write-PSFMessage -Level Error -Message "The request failed with status code: $($statusCode)"
                }

            } while ($continuationToken)

            return @{
                Results = $allResults
                Count = $allResults.Count
            }
        } catch {
            Write-PSFMessage -Level Error -Message "Something went wrong during request to ADO: $($_.ErrorDetails.Message)" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
    }
    end {
        Invoke-TimeSignal -End        
    }
}