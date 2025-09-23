
<#
    .SYNOPSIS
        Retrieves and processes work items from a source Azure DevOps project.
        
    .DESCRIPTION
        This function retrieves work items from a source Azure DevOps project using a WIQL query, splits them into batches of 200, and processes them to extract detailed information.
        
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
        
    .PARAMETER SourceProjectName
        The name of the source Azure DevOps project.
        
    .PARAMETER SourceToken
        The personal access token (PAT) for the source Azure DevOps organization.
        
    .PARAMETER Fields
        (Optional) The fields to retrieve for each work item. Default is a set of common fields including ID, Title, Description, WorkItemType, State, and Parent.
        
    .PARAMETER ApiVersion
        (Optional) The API version to use. Default is `7.1`.
        
    .EXAMPLE
        # Example: Retrieve and process work items from a source project
        
        Get-ADOSourceWorkItemsList -SourceOrganization "source-org" -SourceProjectName "source-project" -SourceToken "source-token"
        
    .NOTES
        This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Get-ADOSourceWorkItemsList {
    [CmdletBinding()]
    # OutputType: emit zero or more PSCustomObject items representing work items
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceOrganization,

        [Parameter(Mandatory = $true)]
        [string]$SourceProjectName,

        [Parameter(Mandatory = $true)]
        [string]$SourceToken,

        [Parameter(Mandatory = $false)]
        [Array]$Fields = @("System.Id", "System.Title", "System.Description", "System.WorkItemType", "System.State", "System.Parent"),

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = "7.1"
    )

    begin {
        # Log the start of the operation
        Write-PSFMessage -Level Verbose -Message "Starting retrieval of work items from project '$SourceProjectName' in organization '$SourceOrganization'."
        Invoke-TimeSignal -Start
    }

    process {
        try {
            # Execute WIQL query to retrieve work items
            Write-PSFMessage -Level Verbose -Message "Executing WIQL query to retrieve work items from project '$SourceProjectName' in organization '$SourceOrganization'."
            $query = "SELECT [System.Id] FROM WorkItems WHERE [System.WorkItemType] NOT IN ('Test Suite', 'Test Plan','Shared Steps','Shared Parameter','Feedback Request') ORDER BY [System.ChangedDate] asc"
            $result = Invoke-ADOWiqlQueryByWiql -Organization $SourceOrganization -Token $SourceToken -Project $SourceProjectName -Query $query -ApiVersion $ApiVersion

            # Log the number of work items retrieved
            Write-PSFMessage -Level Verbose -Message "Retrieved $($result.workItems.Count) work items from the WIQL query."
            if($result.workItems.Count -gt 0)
            {
                # Split the work item IDs into batches of 200
                Write-PSFMessage -Level Verbose -Message "Splitting work item IDs into batches of 200."
                $witListBatches = [System.Collections.ArrayList]::new()
                $batch = @()
                $result.workItems.id | ForEach-Object -Process {
                    $batch += $_
                    if ($batch.Count -eq 200) {
                        Write-PSFMessage -Level Verbose -Message "Adding a batch of 200 work item IDs."
                        $null = $witListBatches.Add($batch)
                        $batch = @()
                    }
                } -End {
                    if ($batch.Count -gt 0) {
                        Write-PSFMessage -Level Verbose -Message "Adding the final batch of $($batch.Count) work item IDs."
                        $null = $witListBatches.Add($batch)
                    }
                }

                # Log the number of batches created
                Write-PSFMessage -Level Verbose -Message "Created $($witListBatches.Count) batches of work item IDs."

                $wiResult = @()
                # Process each batch
                foreach ($witBatch in $witListBatches) {
                    if($witBatch.Count -eq 0 -or $null -eq $witBatch -or $null -eq $witBatch[0]) {
                        continue
                    }
                    Write-PSFMessage -Level Verbose -Message "Processing a batch of $($witBatch.Count) work item IDs."
                    $wiResult += Get-ADOWorkItemsBatch -Organization $SourceOrganization -Token $SourceToken -Project $SourceProjectName -Ids $witBatch -Fields $Fields -ApiVersion $ApiVersion
                }


                # Log the number of work items retrieved in detail
                Write-PSFMessage -Level Verbose -Message "Retrieved detailed information for $($wiResult.Count) work items."

                # Format work items into a list
                $sourceWorkItemsList = $wiResult.fields | ForEach-Object {
                    [PSCustomObject]@{
                        "System.Id"                 = $_."System.Id"
                        "System.WorkItemType"       = $_."System.WorkItemType"
                        "System.Description"        = $_."System.Description"
                        "System.State"              = $_."System.State"
                        "System.Title"              = $_."System.Title"
                        "Custom.SourceWorkitemId"   = $_."Custom.SourceWorkitemId"
                        "System.Parent"             = if ($_.PSObject.Properties["System.Parent"] -and $_."System.Parent") {
                                                        $_."System.Parent"
                                                    } else {
                                                        0
                                                    }
                    }
                }

                # Log the work items retrieved
                Write-PSFMessage -Level Verbose -Message "Formatted work items into a list. Total items: $($sourceWorkItemsList.Count)."
                #$sourceWorkItemsList | Format-Table -AutoSize

                # Emit the formatted work items list (enumerated)
                $sourceWorkItemsList
            }
            else {
                Write-PSFMessage -Level Warning -Message "No work items were retrieved from the source project '$SourceProjectName'."
                [PSCustomObject[]]
            }
            
        } catch {
            # Log the error
            Write-PSFMessage -Level Error -Message "An error occurred: $($_.Exception.Message)"
            Stop-PSFFunction -Message "Stopping because of errors."
        }
    }

    end {
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Completed retrieval of work items from project '$SourceProjectName'."
        Invoke-TimeSignal -End
    }
}