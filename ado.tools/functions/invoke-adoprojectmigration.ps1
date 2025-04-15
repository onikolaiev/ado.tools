
<#
    .SYNOPSIS
        Migrates a project from a source Azure DevOps organization to a target Azure DevOps organization.
        
    .DESCRIPTION
        This function facilitates the migration of a project from one Azure DevOps organization to another.
        It retrieves the source project details, validates its existence, and prepares for migration to the target organization.
        
    .PARAMETER SourceOrganization
        The name of the source Azure DevOps organization.
        
    .PARAMETER TargetOrganization
        The name of the target Azure DevOps organization.
        
    .PARAMETER SourceProjectName
        The name of the project in the source organization to be migrated.
        
    .PARAMETER TargetProjectName
        The name of the project in the target organization where the source project will be migrated.
        
    .PARAMETER SourceOrganizationToken
        The authentication token for accessing the source Azure DevOps organization.
        
    .PARAMETER TargetOrganizationToken
        The authentication token for accessing the target Azure DevOps organization.
        
    .PARAMETER ApiVersion
        The version of the Azure DevOps REST API to use. Default is "7.1".

    .EXAMPLE
        $sourceOrg = "sourceOrg"
        $targetOrg = "targetOrg"
        $sourceProjectName = "sourceProject"
        $targetProjectName = "targetProject"
        $sourceOrgToken = "sourceOrgToken"
        $targetOrgToken = "targetOrgToken"

        Invoke-ADOProjectMigration -SourceOrganization $sourceOrg `
                                   -TargetOrganization $targetOrg `
                                   -SourceProjectName $sourceProjectName `
                                   -TargetProjectName $targetProjectName `
                                   -SourceOrganizationToken $sourceOrgToken `
                                   -TargetOrganizationToken $targetOrgToken
                                 
        This example migrates the project "sourceProject" from the organization "sourceOrg" to the organization "targetOrg".
        
    .NOTES
        This function uses PSFramework for logging and exception handling.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Invoke-ADOProjectMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceOrganization,

        [Parameter(Mandatory = $true)]
        [string]$TargetOrganization,

        [Parameter(Mandatory = $true)]
        [string]$SourceProjectName,

        [Parameter(Mandatory = $true)]
        [string]$TargetProjectName,

        [Parameter(Mandatory = $true)]
        [string]$SourceOrganizationToken,

        [Parameter(Mandatory = $true)]
        [string]$TargetOrganizationToken,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $Script:ADOApiVersion
    )
    begin{
        Invoke-TimeSignal -Start
    }
    process{
        if (Test-PSFFunctionInterrupt) { return }

        # Log start of migration
        Write-PSFMessage -Level Host -Message "Starting migration from source organization '$sourceOrganization' to target organization '$targetOrganization'."

        ## GETTING THE SOURCE PROJECT INFORMATION
        Write-PSFMessage -Level Host -Message "Fetching source project '$sourceProjectName' from organization '$sourceOrganization'."
        $sourceProjecttmp = (Get-ADOProjectList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -StateFilter All).Where({$_.name -eq $sourceProjectName})
        if (-not $sourceProjecttmp) {
            Write-PSFMessage -Level Error -Message "Source project '$sourceProjectName' not found in organization '$sourceOrganization'. Exiting."
            return
        }
        Write-PSFMessage -Level Host -Message "Source project '$sourceProjectName' found. Fetching detailed information."
        $sourceProject = Get-ADOProject -Organization $sourceOrganization -Token $sourceOrganizationtoken -ProjectId "$($sourceProjecttmp.id)" -IncludeCapabilities
        $sourceProjectVersionControl = $sourceProject.capabilities.versioncontrol
        $sourceProjectProcess = Get-ADOProcess -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessTypeId "$($sourceProject.capabilities.processTemplate.templateTypeId)"
        $sourceProjectProcessParentProcess = Get-ADOProcess -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessTypeId "$($sourceProjectProcess.parentProcessTypeId)"

        Write-PSFMessage -Level Host -Message "Source project process: '$($sourceProjectProcess.name)' (ID: $($sourceProjectProcess.typeId))."

        ### PROCESSING PROCESS
        Write-PSFMessage -Level Host -Message "Checking if target process '$($sourceProjectProcess.name)' exists in target organization '$targetOrganization'."
        $targetProjectProcess = (Get-ADOProcessList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion).Where({$_.name -eq $sourceProjectProcess.name})

        ## Check if the target process already exists. If not, create it.
        if (-not $targetProjectProcess) {
            Write-PSFMessage -Level Host -Message "Target process '$($sourceProjectProcess.name)' does not exist. Creating it in target organization '$targetOrganization'."
            $body = @{
                name = $sourceProjectProcess.name
                parentProcessTypeId = $sourceProjectProcessParentProcess.typeId
                description = $sourceProjectProcess.description
                customizationType = $sourceProjectProcess.customizationType
                isEnabled = "true"
            }
            $body = $body | ConvertTo-Json -Depth 10    
            Write-PSFMessage -Level Verbose -Message "Adding process '$($sourceProjectProcess.name)' to target organization '$($targetOrganization)' with the following details: $($body)"
            $targetProjectProcess = Add-ADOProcess -Organization $targetOrganization -Token $targetOrganizationtoken -Body $body
        } else {
            Write-PSFMessage -Level Host -Message "Target process '$($sourceProjectProcess.name)' already exists in target organization '$targetOrganization'."
        }

        ## PROCESSING WIT FIELDS
        Write-PSFMessage -Level Host -Message "Fetching custom work item fields from source organization '$sourceOrganization'."
        $sourceWitFields = (Get-ADOWitFieldList -Organization $sourceOrganization -Token $sourceOrganizationtoken -Expand "extensionFields").Where({$_.referenceName.startswith("Custom.")})
        Write-PSFMessage -Level Host -Message "Found $($sourceWitFields.Count) custom fields in source organization."

        Write-PSFMessage -Level Host -Message "Fetching custom work item fields from target organization '$targetOrganization'."
        $targetWitFields = (Get-ADOWitFieldList -Organization $targetOrganization -Token $targetOrganizationtoken -Expand "extensionFields").Where({$_.referenceName.startswith("Custom.")})
        Write-PSFMessage -Level Host -Message "Found $($targetWitFields.Count) custom fields in target organization."

        $sourceWitFields | ForEach-Object {
            $witField = $_
            $targetWitField = $targetWitFields.Where({$_.name -eq $witField.name})
            
            if (-not $targetWitField) {
                Write-PSFMessage -Level Host -Message "Custom field '$($witField.name)' does not exist in target organization. Adding it."
                $sourceWitField = Get-ADOWitField -Organization $sourceOrganization -Token $sourceOrganizationtoken -FieldNameOrRefName "$($witField.referenceName)" 
                $body = @{
                    name = $sourceWitField.name
                    referenceName = $sourceWitField.referenceName
                    description = $sourceWitField.description
                    type = $sourceWitField.type
                    usage = $sourceWitField.usage
                    readOnly = $sourceWitField.readOnly
                    isPicklist = $sourceWitField.isPicklist
                    isPicklistSuggested = $sourceWitField.isPicklistSuggested
                    isIdentity = $sourceWitField.isIdentity
                    isQueryable = $sourceWitField.isQueryable
                    isLocked = $sourceWitField.isLocked
                    canSortBy = $sourceWitField.canSortBy
                    supportedOperations = $sourceWitField.supportedOperations
                }

                $body = $body | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Verbose -Message "Adding custom field '$($sourceWitField.name)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                $targetWitField = Add-ADOWitField -Organization $targetOrganization -Token $targetOrganizationtoken -Body $body
            } else {
                Write-PSFMessage -Level Host -Message "Custom field '$($witField.name)' already exists in target organization. Skipping."
            }
        }
        ### Creating RelatedWorkitemId field for the target organization
        $relatedWorkitemIdFieldName = "RelatedWorkitemId"
        $relatedWorkitemIdReferenceName = "Custom.$relatedWorkitemIdFieldName"
        $body = @{
            name = $referenceWorkitemId
            referenceName = "$relatedWorkitemIdReferenceName"
            description = ""
            type = "string"
            usage = "workItem"
            readOnly = $false
            isQueryable = $true
            isLocked = $false
            canSortBy = $true
        }
        
        $body = $body | ConvertTo-Json -Depth 10
        
        Add-ADOWitField -Organization $targetOrganization -Token $targetOrganizationtoken -Body $body
        
        ## PROCESSING WORK ITEM TYPES
        Write-PSFMessage -Level Host -Message "Fetching custom work item types from source process '$($sourceProjectProcess.name)'."
        $sourceWitList = (Get-ADOWorkItemTypeList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -Expand layout).Where({$_.customization -eq 'inherited'})
        Write-PSFMessage -Level Host -Message "Found $($sourceWitList.Count) custom work item types in source process."

        Write-PSFMessage -Level Host -Message "Fetching custom work item types from target process '$($targetProjectProcess.name)'."
        $targetWitList = (Get-ADOWorkItemTypeList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -Expand layout).Where({$_.customization -eq 'inherited'})
        Write-PSFMessage -Level Host -Message "Found $($targetWitList.Count) custom work item types in target process."

        $sourceWitList | ForEach-Object {
            $wit = $_
            $targetWit = $targetWitList.Where({$_.name -eq $wit.name})
            
            if (-not $targetWit) {
                Write-PSFMessage -Level Host -Message "Work item type '$($wit.name)' does not exist in target process. Adding it."
                $sourceWit = Get-ADOWorkItemType -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName "$($wit.referenceName)"
                $body = @{
                    name = $sourceWit.name
                    description = $sourceWit.description
                    color = $sourceWit.color
                    icon = $sourceWit.icon
                    isDisabled = $sourceWit.isDisabled
                    inheritsFrom = $sourceWit.inherits
                }
                $body = $body | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Verbose -Message "Adding work item type '$($sourceWit.name)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                $targetWit = Add-ADOWorkItemType -Organization $targetOrganization -Token $targetOrganizationtoken -ProcessId "$($targetProjectProcess.typeId)" -Body $body
            } else {
                Write-PSFMessage -Level Host -Message "Work item type '$($wit.name)' already exists in target process. Skipping."
            }
        }
        $targetWitList = (Get-ADOWorkItemTypeList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -Expand layout).Where({$_.customization -eq 'inherited'})

        ## Process Fields
        Write-PSFMessage -Level Host -Message "Starting to process custom fields for work item types."
        $sourceWitList | ForEach-Object {
            $wit = $_
            Write-PSFMessage -Level Host -Message "Processing fields for work item type '$($wit.name)'."
            $targetWit = $targetWitList.Where({$_.name -eq $wit.name})
            $customFields = (Get-ADOWorkItemTypeFieldList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName $wit.referenceName).Where({$_.customization -ne "system"})
            $customFields | ForEach-Object {
                $field = $_
                Write-PSFMessage -Level Host -Message "Checking field '$($field.name)' in target process."
                $targetField = (Get-ADOWorkItemTypeFieldList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName $targetWit.referenceName).Where({$_.name -eq $field.name})
                
                if (-not $targetField) {
                    Write-PSFMessage -Level Host -Message "Field '$($field.name)' does not exist in target process. Adding it."
                    $sourceField = Get-ADOWorkItemTypeField -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName "$($wit.referenceName)" -FieldRefName "$($field.referenceName)" -Expand all
                    $body = @{
                        allowGroups = $sourceField.allowGroups
                        allowedValues = $sourceField.allowedValues
                        description = $sourceField.description
                        defaultValue = $sourceField.defaultValue
                        readOnly = $sourceField.readOnly
                        referenceName = $sourceField.referenceName
                        required = $sourceField.required
                    }
                    $body = $body | ConvertTo-Json -Depth 10
                    Write-PSFMessage -Level Verbose -Message "Adding field '$($sourceField.name)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                    $targetField = Add-ADOWorkItemTypeField -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName $targetWit.referenceName -Body $body
                } else {
                    Write-PSFMessage -Level Host -Message "Field '$($field.name)' already exists in target process. Skipping."
                }
            } 
        }

        ## Process Behaviors
        Write-PSFMessage -Level Host -Message "Starting to process behaviors for work item types."
        $sourceWitList | ForEach-Object {
            $wit = $_
            Write-PSFMessage -Level Host -Message "Processing behaviors for work item type '$($wit.name)'."
            #$targetWit = $targetWitList.Where({$_.name -eq $wit.name})  
            $sourceBehaviors = (Get-ADOProcessBehaviorList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -Expand "fields")
            $targetBehaviors = (Get-ADOProcessBehaviorList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -Expand "fields")
            $sourceBehaviors | ForEach-Object {
                $behavior = $_
                Write-PSFMessage -Level Host -Message "Checking behavior '$($behavior.name)' in target process."
                $targetBehavior = $targetBehaviors.Where({$_.name -eq $behavior.name})
                
                if (-not $targetBehavior) {
                    Write-PSFMessage -Level Verbose -Message "Behavior '$($behavior.name)' does not exist in target process. Adding it."
                    $sourceBehavior = Get-ADOProcessBehavior -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -BehaviorRefName "$($behavior.referenceName)"  -Expand "fields"
                    $body = @{
                        color = $sourceBehavior.color
                        inherits = $sourceBehavior.inherits
                        name = $sourceBehavior.name
                        referenceName = $sourceBehavior.referenceName
                    }
                    $body = $body | ConvertTo-Json -Depth 10
                    Write-PSFMessage -Level Host -Message "Adding behavior '$($sourceBehavior.name)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                    $targetBehavior = Add-ADOProcessBehavior -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -Body $body
                } else {
                    Write-PSFMessage -Level Host -Message "Behavior '$($behavior.name)' already exists in target process. Skipping."
                }
            }
        }

        ## Process Picklists
        Write-PSFMessage -Level Host -Message "Starting to process picklists."
        $sourcePicklists = (Get-ADOPickListList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion)
        $targetPicklists = (Get-ADOPickListList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion)
        $sourcePicklists | ForEach-Object {
            $picklist = $_
            Write-PSFMessage -Level Host -Message "Checking picklist '$($picklist.name)' in target process."
            $targetPicklist = $targetPicklists.Where({$_.name -eq $picklist.name})
            
            if (-not $targetPicklist) {
                Write-PSFMessage -Level Verbose -Message "Picklist '$($picklist.name)' does not exist in target process. Adding it."
                $sourcePicklist = Get-ADOPickList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ListId "$($picklist.id)"
                $body = @{
                    name = $sourcePicklist.name
                    type = $sourcePicklist.type
                    isSuggested = $sourcePicklist.isSuggested
                    items = $sourcePicklist.items
                }
                $body = $body | ConvertTo-Json -Depth 10
                Write-PSFMessage -Level Host -Message "Adding picklist '$($sourcePicklist.name)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                $targetPicklist = Add-ADOPickList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -Body $body
            } else {
                Write-PSFMessage -Level Host -Message "Picklist '$($picklist.name)' already exists in target process. Skipping."
            }
        }

        ## Process States
        Write-PSFMessage -Level Host -Message "Starting to process states for work item types."
        $sourceWitList | ForEach-Object {
            $wit = $_
            Write-PSFMessage -Level Host -Message "Processing states for work item type '$($wit.name)'."
            $targetWit = $targetWitList.Where({$_.name -eq $wit.name})  
            $sourceStates = (Get-ADOWorkItemTypeStateList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName "$($wit.referenceName)")
            $targetStates = (Get-ADOWorkItemTypeStateList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)")
            $sourceStates | ForEach-Object {
                $state = $_
                Write-PSFMessage -Level Host -Message "Checking state '$($state.name)' in target process."
                $targetState = $targetStates.Where({$_.name -eq $state.name})
                $sourceState = Get-ADOWorkItemTypeState -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName "$($wit.referenceName)" -StateId "$($state.id)"
                    
                if (-not $targetState) {
                    Write-PSFMessage -Level Host -Message "State '$($state.name)' does not exist in target process. Adding it."
                    $body = @{
                        name = $sourceState.name
                        color = $sourceState.color
                        stateCategory = $sourceState.stateCategory
                        order = $sourceState.order
                    }
                    $body = $body | ConvertTo-Json -Depth 10
                    Write-PSFMessage -Level Verbose -Message "Adding state '$($sourceState.name)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                    $targetState = Add-ADOWorkItemTypeState -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -Body $body
                } else {
                    Write-PSFMessage -Level Host -Message "State '$($state.name)' already exists in target process. Skipping."
                }

                if ($sourceState.hidden) { 
                    Write-PSFMessage -Level Verbose -Message "Hiding state '$($sourceState.name)' in target process."
                    $targetState = Hide-ADOWorkItemTypeState -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -StateId "$($targetState.id)" -Hidden "true"
                }   
            }
        }
        ## Process Rules
        Write-PSFMessage -Level Host -Message "Starting to process rules for work item types."
        $sourceWitList | ForEach-Object {
            $wit = $_
            Write-PSFMessage -Level Host -Message "Processing rules for work item type '$($wit.name)'."
            $targetWit = $targetWitList.Where({$_.name -eq $wit.name})    
            $sourceRules = (Get-ADOWorkItemTypeRuleList -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName "$($wit.referenceName)").Where({$_.customizationType -ne 'system'})  
            $targetRules = (Get-ADOWorkItemTypeRuleList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)").Where({$_.customizationType -ne 'system'}) 
            $sourceRules | ForEach-Object {
                $rule = $_
                Write-PSFMessage -Level Host -Message "Checking rule '$($rule.name)' in target process."
                $targetRule = $targetRules.Where({$_.name -eq $rule.name})
                if (-not $targetRule) {
                    Write-PSFMessage -Level Host -Message "Rule '$($rule.name)' does not exist in target process. Adding it."
                    $sourceRule = Get-ADOWorkItemTypeRule -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName "$($wit.referenceName)" -RuleRefName "$($rule.referenceName)"
                    $body = @{
                        name = $sourceRule.name
                        conditions = $sourceRule.conditions
                        actions = $sourceRule.actions
                        isDisabled = $sourceRule.isDisabled
                    }
                    $body = $body | ConvertTo-Json -Depth 10
                    Write-PSFMessage -Level Host -Message "Adding rule '$($sourceRule.name)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                    $targetRule = Add-ADOWorkItemTypeRule -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -Body $body
                } else {
                    Write-PSFMessage -Level Host -Message "Rule '$($rule.name)' already exists in target process. Skipping."
                }
            }
        }

        ## Process Layouts
        Write-PSFMessage -Level Host -Message "Starting to process layouts for work item types."
        $sourceWitList | ForEach-Object {
            $wit = $_
            Write-PSFMessage -Level Host -Message "Processing layouts for work item type '$($wit.name)'."
            $targetWit = $targetWitList.Where({$_.name -eq $wit.name})
            $sourceLayout = (Get-ADOWorkItemTypeLayout -Organization $sourceOrganization -Token $sourceOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($sourceProjectProcess.typeId)" -WitRefName "$($wit.referenceName)")    
            $targetLayout = (Get-ADOWorkItemTypeLayout -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)")
            $sourceLayout.pages | Where-Object pageType -EQ "custom" | ForEach-Object {
                $sourcePage = $_
                Write-PSFMessage -Level Host -Message "Processing page '$($sourcePage.label)' for work item type '$($wit.name)'."
                $targetPage = $targetLayout.pages.Where({$_.label -eq $sourcePage.label})   
                if (-not $targetPage) {
                    Write-PSFMessage -Level Host -Message "Page '$($sourcePage.label)' does not exist in target process. Adding it."
                    $body = @{
                        id = $sourcePage.id
                        label = $sourcePage.label
                        pageType = $sourcePage.pageType
                        visible = $sourcePage.visible
                    }
                    $body = $body | ConvertTo-Json -Depth 10
                    Write-PSFMessage -Level Verbose -Message "Adding page '$($sourcePage.label)' to target process '$($targetProjectProcess.name)' with the following details: $($body)"
                    $targetPage = Add-ADOWorkItemTypePage -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -Body $body
                } else {
                    Write-PSFMessage -Level Host -Message "Page '$($sourcePage.label)' already exists in target process. Updating it."
                    $body = @{
                        id = $targetPage.id
                        label = $sourcePage.label
                        pageType = $sourcePage.pageType
                        visible = $sourcePage.visible
                    }
                    $body = $body | ConvertTo-Json -Depth 10
                    Write-PSFMessage -Level Verbose -Message "Updating page '$($sourcePage.label)' in target process '$($targetProjectProcess.name)' with the following details: $($body)"
                    $null = Update-ADOWorkItemTypePage -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -Body $body
                }

                # Process Sections
                $sourcePageSections = $sourcePage.sections
                $targetPageSections = $targetPage.sections
                $sourcePageSections | Where-Object groups -NE $NULL | ForEach-Object {
                    $sourceSection = $_
                    Write-PSFMessage -Level Host -Message "Processing section ''$(if($sourceSection.label){$sourceSection.label}else{$sourceSection.id})' on page '$($sourcePage.label)'."
                    $targetSection = $targetPageSections.Where({$_.id -eq $sourceSection.id})
                    if (-not $targetSection) {
                        Write-PSFMessage -Level Host -Message "Section '$(if($sourceSection.label){$sourceSection.label}else{$sourceSection.id})' does not exist in target process. Adding it."
                        $body = @{
                            id = $sourceSection.id
                            label = $sourceSection.label
                            visible = $sourceSection.visible
                        }
                        $body = $body | ConvertTo-Json -Depth 10
                        Write-PSFMessage -Level Verbose -Message "Adding section '$(if($sourceSection.label){$sourceSection.label}else{$sourceSection.id})' to page '$($targetPage.label)' in target process '$($targetProjectProcess.name)' with the following details: $($body)"
                        $targetSection = Add-ADOWorkItemTypeSection -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -PageId "$($targetPage.id)" -Body $body
                    } else {
                        Write-PSFMessage -Level Host -Message "Section '$(if($sourceSection.label){$sourceSection.label}else{$sourceSection.id})' already exists in target process. Skipping."
                    }

                    # Process Groups
                    $sourceSection.groups | ForEach-Object {
                        $sourceGroup = $_
                        Write-PSFMessage -Level Host -Message "Processing group '$($sourceGroup.label)' in section '$($sourceSection.label)'."
                        $targetGroup = $targetSection.groups.Where({$_.label -eq $sourceGroup.label})
                        if (-not $targetGroup) {
                            Write-PSFMessage -Level Host -Message "Group '$($sourceGroup.label)' does not exist in target process. Adding it."
                            $body = @{
                                id = $sourceGroup.id
                                label = $sourceGroup.label
                                visible = $sourceGroup.visible
                                controls = $sourceGroup.controls
                            }
                            $body = $body | ConvertTo-Json -Depth 10
                            Write-PSFMessage -Level Verbose -Message "Adding group '$($sourceGroup.label)' to section '$($sourceSection.label)' on page '$($targetPage.label)' in target process '$($targetProjectProcess.name)' with the following details: $($body)"
                            $targetGroup = Add-ADOWorkItemTypeGroup -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -PageId "$($targetPage.id)" -SectionId "$($sourceSection.id)" -Body $body
                        } else {
                            Write-PSFMessage -Level Host -Message "Group '$($sourceGroup.label)' already exists in target process. Skipping."
                        }

                        # Process Controls
                        $sourceGroup.controls | ForEach-Object {
                            $sourceControl = $_
                            Write-PSFMessage -Level Host -Message "Processing control '$(if($sourceControl.label){$sourceControl.label}else{$sourceControl.id})' in group '$($sourceGroup.label)'."
                            $targetControl = $targetGroup.controls.Where({$_.id -eq $sourceControl.id})
                            if (-not $targetControl) {
                                Write-PSFMessage -Level Host -Message "Control '$(if($sourceControl.label){$sourceControl.label}else{$sourceControl.id})' does not exist in target process. Adding it."
                                $body = @{
                                    id = $sourceControl.id
                                    label = $sourceControl.label
                                    controlType = $sourceControl.controlType
                                    contribution = $sourceControl.contribution
                                    visible = $sourceControl.visible
                                    height = $sourceControl.height
                                    readOnly = $sourceControl.readOnly
                                }
                                $body = $body | ConvertTo-Json -Depth 10
                                Write-PSFMessage -Level Verbose -Message "Adding control '$(if($sourceControl.label){$sourceControl.label}else{$sourceControl.id})' to group '$($sourceGroup.label)' in target process '$($targetProjectProcess.name)' with the following details: $($body)"
                                $targetControl = Add-ADOWorkItemTypeGroupControl -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -ProcessId "$($targetProjectProcess.typeId)" -WitRefName "$($targetWit.referenceName)" -GroupId "$($targetGroup.id)" -Body $body
                            } else {
                                Write-PSFMessage -Level Host -Message "Control '$(if($sourceControl.label){$sourceControl.label}else{$sourceControl.id})' already exists in target process. Skipping."
                            }
                        }
                    }
                }
            }
        }

        ### PROCESSING PROJECT


        Write-PSFMessage -Level Host -Message "Fetching source project '$($sourceProjecttmp.name)' from organization '$($sourceOrganization)'."
        $sourceProject = Get-ADOProject -Organization $sourceOrganization -Token $sourceOrganizationtoken -ProjectId "$($sourceProjecttmp.id)" -IncludeCapabilities

        Write-PSFMessage -Level Host -Message "Checking if target project '$($sourceProjectName)' exists in organization '$($targetOrganization)'."
        $targetProject = (Get-ADOProjectList -Organization $targetOrganization -Token $targetOrganizationtoken -ApiVersion $apiVersion -StateFilter All).Where({$_.name -eq $sourceProjectName})

        if (-not $targetProject) {
            Write-PSFMessage -Level Verbose -Message "Target project '$($targetProjectName)' does not exist in organization '$($targetOrganization)'. Creating a new project."

            $body = @{
                name = $targetProjectName
                description = $sourceProject.description
                visibility = $sourceProject.visibility
                capabilities = @{
                    versioncontrol = @{
                        sourceControlType = $sourceProjectVersionControl.sourceControlType
                    }
                    processTemplate = @{
                        templateTypeId = $targetProjectProcess.typeId
                    }
                }
            }
            $body = $body | ConvertTo-Json -Depth 10

            Write-PSFMessage -Level Host -Message "Adding project '$($targetProjectName)' to target organization '$($targetOrganization)' with the following details: $($body)"
            $targetProject = Add-ADOProject -Organization $targetOrganization -Token $targetOrganizationtoken -Body $body

            Write-PSFMessage -Level Host -Message "Project '$($targetProjectName)' successfully created in target organization '$($targetOrganization)'."
        } else {
            Write-PSFMessage -Level Host -Message "Target project '$($targetProjectName)' already exists in organization '$($targetOrganization)'. Updating the project."

            $body = @{
                name = $targetProjectName
                description = $sourceProject.description
                visibility = $sourceProject.visibility
                capabilities = @{
                    versioncontrol = @{
                        sourceControlType = $sourceProjectVersionControl.sourceControlType
                    }
                    processTemplate = @{
                        templateTypeId = $targetProjectProcess.typeId
                    }
                }
            }
            $body = $body | ConvertTo-Json -Depth 10

            Write-PSFMessage -Level Host -Message "Updating project '$($targetProjectName)' in target organization '$($targetOrganization)' with the following details: $($body)"
            $targetProject = Update-ADOProject -Organization $targetOrganization -Token $targetOrganizationtoken -Body $body -ProjectId "$($targetProject.id)"

            Write-PSFMessage -Level Host -Message "Project '$($targetProjectName)' successfully updated in target organization '$($targetOrganization)'."
        }

        #PROCESSING WORK ITEM
        $sourceWorkItemsList = (Get-ADOSourceWorkItemsList -SourceOrganization $sourceOrganization -SourceProjectName $sourceProjectName -SourceToken $sourceOrganizationtoken)
        $targetWorkItemList = @{}
     
        $sourceWorkItemsList |  ForEach-Object {
            $sourceWorkItem = $_
            Invoke-ADOWorkItemsProcessing -SourceWorkItem $sourceWorkItem -SourceOrganization $sourceOrganization -SourceProjectName $sourceProjectName -SourceToken $sourceOrganizationtoken -TargetOrganization $targetOrganization `
            -TargetProjectName $targetProjectName -TargetToken $targetOrganizationtoken `
            -TargetWorkItemList ([ref]$targetWorkItemList) -ApiVersion $ApiVersion
        }

        # Log the completion of the migration process
        Write-PSFMessage -Level Host -Message "Completed migration of work items from project '$sourceProjectName' in organization '$sourceOrganization' to project '$targetProjectName' in organization '$targetOrganization'."

    }
    end{
        # Log the end of the operation
        Write-PSFMessage -Level Host -Message "Migration from source organization '$sourceOrganization' to target organization '$targetOrganization' completed successfully."
        Invoke-TimeSignal -End
    }
}