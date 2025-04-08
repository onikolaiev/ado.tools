# Sample usage script for Invoke-ADOApiRequest function

# Define variables
$organization = "ciellos-bc" # Replace with your Azure DevOps organization name
$project = "Q-Mation BC Implementation"  # Replace with your Azure DevOps project name (optional)
$token = "1n27IjhGH64PTlMU95AQr7OxdcTHpvzXpbmPeblXbNwTARY3E4LMJQQJ99BCACAAAAAlnrgIAAAGAZDO47eB" # Replace with your Azure DevOps PAT
$apiVersion = "7.1" # API version
$apiUri = "_apis/projects" # Example API URI to list all projects
$method = "GET" # HTTP method
Enable-ADOException

$project = Get-ADOProjectList -Organization $organization -Token $token -ApiVersion $apiVersion -StateFilter All -Top 1
$response = Get-ADOProject -Organization $organization -Token $token -ProjectId "$($project.id)" -IncludeCapabilities
$response




$body = @"
[
    {
        "op": "remove",
        "path": "/Alias"
    }
]
"@

Set-ADOProjectProperties -Organization $organization -Token $token -ProjectId "$($project.id)" -ApiVersion "7.1-preview" -Body $body
Get-ADOProjectProperties -Organization $organization -Token $token -ProjectId "$($project.id)" -ApiVersion "7.1-preview"

$body = @"
{
    "description": ""
}
"@

Update-ADOProject -Organization $organization -Token $token -ProjectId "$($project.id)" -Body $body
Get-ADOProject -Organization $organization -Token $token -ProjectId "$($project.id)" -IncludeCapabilities


Get-ADOProcessList -Organization $organization -Token $token -ApiVersion $apiVersion
Get-ADOWorkItemTypeList -Organization $organization -Token $token -ApiVersion $apiVersion -ProcessId "9da2b0bc-33e9-4143-a7f8-cd49b7c2035d" -Expand layout
Get-ADOWorkItemType -Organization $organization -Token $token -ApiVersion $apiVersion -ProcessId "9da2b0bc-33e9-4143-a7f8-cd49b7c2035d" -WitRefName "Scrum-Ciellos-Training.Bug"
$body = @"
{
    "name": "TEST Change Request",
    "description": "Tracks requests for changes",
    "color": "f6546a",
    "icon": "icon_airplane",
    "isDisabled": false,
    "inheritsFrom": null
}
"@
Add-ADOWorkItemType -Organization $organization -Token $token -ApiVersion $apiVersion -ProcessId "9da2b0bc-33e9-4143-a7f8-cd49b7c2035d" -Body $body
$body = @"
{
    "name": "TEST Change Request",
    "description": "Tracks requests for changes updated",
    "color": "f6546a",
    "icon": "icon_airplane",
    "isDisabled": false,
    "inheritsFrom": null
}
"@
Update-ADOWorkItemType -Organization $organization -Token $token -ApiVersion $apiVersion -ProcessId "9da2b0bc-33e9-4143-a7f8-cd49b7c2035d" -WitRefName "Scrum-Ciellos-Training.TESTChangeRequest" -Body $body 





Get-ADOWorkItemTypeFieldList -Organization $organization -Token $token -ApiVersion $apiVersion -ProcessId "9da2b0bc-33e9-4143-a7f8-cd49b7c2035d" -WitRefName "Scrum-Ciellos-Training.TESTChangeRequest"

Remove-ADOWorkItemType -Organization $organization -Token $token -ApiVersion $apiVersion -ProcessId "9da2b0bc-33e9-4143-a7f8-cd49b7c2035d" -WitRefName "Scrum-Ciellos-Training.TESTChangeRequest"

Get-ADOProcessBehaviorList -Organization $organization -Token $token -ApiVersion $apiVersion -ProcessId "9da2b0bc-33e9-4143-a7f8-cd49b7c2035d" -Expand "fields"

Get-ADOPickListList -Organization $organization -Token $token

Get-ADOProcessList -Organization $organization -Token $token