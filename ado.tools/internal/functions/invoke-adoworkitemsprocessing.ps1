
<#
    .SYNOPSIS
        Processes a source work item from Azure DevOps and creates or updates a corresponding work item in the target Azure DevOps project, maintaining parent-child relationships.
        
    .DESCRIPTION
        This function processes a source work item retrieved from Azure DevOps, builds the necessary JSON payload, and creates or updates a corresponding work item in the target Azure DevOps project. It also handles parent-child relationships by linking the work item to its parent if applicable. If the parent work item does not exist in the target project, it is created first.
        
    .PARAMETER SourceWorkItem
        The source work item object containing the fields to process.
        
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
        
    .PARAMETER SourceProjectName
        The name of the source Azure DevOps project.
        
    .PARAMETER SourceToken
        The personal access token (PAT) for the source Azure DevOps organization.
        
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
        
    .PARAMETER TargetProjectName
        The name of the target Azure DevOps project.
        
    .PARAMETER TargetToken
        The personal access token (PAT) for the target Azure DevOps organization.
        
    .PARAMETER TargetWorkItemList
        A hashtable containing mappings of source work item IDs to target work item URLs for parent-child relationships. Passed by reference.
        
    .PARAMETER ApiVersion
        (Optional) The API version to use. Default is `7.1`.
        
    .EXAMPLE
        # Example 1: Process a single work item and create it in the target project
        
        Invoke-ADOWorkItemsProcessing -SourceWorkItem $sourceWorkItem -SourceOrganization "source-org" `
        -SourceProjectName "source-project" -SourceToken "source-token" `
        -TargetOrganization "target-org" -TargetProjectName "target-project" `
        -TargetToken "target-token" -TargetWorkItemList ([ref]$targetWorkItemList)
        
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Invoke-ADOWorkItemsProcessing { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SourceWorkItem,

        [Parameter(Mandatory = $true)]
        [string]$SourceOrganization,

        [Parameter(Mandatory = $true)]
        [string]$SourceProjectName,

        [Parameter(Mandatory = $true)]
        [string]$SourceToken,

        [Parameter(Mandatory = $true)]
        [string]$TargetOrganization,

        [Parameter(Mandatory = $true)]
        [string]$TargetProjectName,

        [Parameter(Mandatory = $true)]
        [string]$TargetToken,

        [Parameter(Mandatory = $true)]
        [ref]$TargetWorkItemList,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $Script:ADOApiVersion
    )

    begin {
        # Log the start of the operation
        Write-PSFMessage -Level Host -Message "Processing work item ID: $($SourceWorkItem.'System.Id'). Title: $($SourceWorkItem.'System.Title')."
    }

    process {
        try {
            # Build the JSON payload for the new work item
            $body = @(
                @{
                    op    = "add"
                    path  = "/fields/System.Title"
                    value = "$($SourceWorkItem."System.Title")"
                }
                @{
                    op    = "add"
                    path  = "/fields/System.Description"
                    value = "$($SourceWorkItem."System.Description")"
                }
                @{
                    op    = "add"
                    path  = "/fields/Custom.RelatedWorkitemId"
                    value = "$($SourceWorkItem."System.ID")"
                }
                @{
                    op    = "add"
                    path  = "/fields/System.State"
                    value = "$($SourceWorkItem."System.State")"
                }
            )

            # Handle parent-child relationships
            if ($SourceWorkItem."System.Parent") {
                if (-not $TargetWorkItemList.Value[$SourceWorkItem."System.Parent"]) {
                    Write-PSFMessage -Level Verbose -Message "Parent work item ID $($SourceWorkItem.'System.Parent') not found in target work item list. Creating it..."
                    $SourceWorkItemsList = (Get-ADOSourceWorkItemsList -SourceOrganization $sourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken)
                    $parentWorkItem = $SourceWorkItemsList | Where-Object { $_."System.Id" -eq $SourceWorkItem.'System.Parent' }
                    # Create the parent work item first
                    Invoke-ADOWorkItemsProcessing -SourceWorkItem $parentWorkItem -SourceOrganization $SourceOrganization -SourceProjectName $SourceProjectName -SourceToken $SourceToken -TargetOrganization $TargetOrganization `
                        -TargetProjectName $TargetProjectName -TargetToken $TargetToken `
                        -TargetWorkItemList ($TargetWorkItemList) -ApiVersion $ApiVersion                  
                } 
                
                
                $body += @{
                    op    = "add"
                    path  = "/relations/-"
                    value = @{
                        rel = "System.LinkTypes.Hierarchy-Reverse"
                        url = "$(($TargetWorkItemList).Value[$SourceWorkItem."System.Parent"])"
                        attributes = @{
                            comment = "Making a new link for the dependency"
                        }
                    }
                }
                
            }

            # Convert the payload to JSON
            $body = $body | ConvertTo-Json -Depth 10
            # Log the creation of the target work item 
            Write-PSFMessage -Level Verbose -Message "Creating target work item for source work item ID: $($SourceWorkItem.'System.Id')."

            # Call the Add-ADOWorkItem function to create the work item
            $targetWorkItem = Add-ADOWorkItem -Organization $TargetOrganization `
                                              -Token $TargetToken `
                                              -Project $TargetProjectName `
                                              -Type "`$$($SourceWorkItem."System.WorkItemType")" `
                                              -Body $body `
                                              -ApiVersion $ApiVersion

            if(-not $targetWorkItem.url) {
                # Add the target work item URL to the TargetWorkItemList
                Write-PSFMessage -Level Error -Message "Error: $($targetWorkItem.url) for source work item ID: $($SourceWorkItem.'System.Id')."
            }
            # Log the successful creation of the target work items list
            $TargetWorkItemList.Value[$SourceWorkItem.'System.Id'] = $targetWorkItem.url

        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "Failed to process work item ID: $($SourceWorkItem.'System.Id'). Error: $($_)"
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Host -Message "Completed processing of work item ID: $($SourceWorkItem.'System.Id')."
    }
}