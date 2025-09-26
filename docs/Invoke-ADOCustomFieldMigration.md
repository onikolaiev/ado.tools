---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Invoke-ADOCustomFieldMigration

## SYNOPSIS
Migrate custom work item fields from source to target organization.

## SYNTAX

```
Invoke-ADOCustomFieldMigration [-SourceOrganization] <String> [-TargetOrganization] <String>
 [-SourceToken] <String> [-TargetToken] <String> [-TargetProcessName] <String> [-ApiVersion] <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function migrates custom work item fields (those starting with 'Custom.') from a source organization to a target organization.

## EXAMPLES

### EXAMPLE 1
```
$apiVersion = '7.1'
$sourceOrg  = 'srcOrg'
$targetOrg  = 'tgtOrg'
$sourceToken = 'pat-src'
$targetToken = 'pat-tgt'
$sourceProjectName = 'Sample'
```

# Obtain source project & process to derive target process name
$sourceProjectMeta = (Get-ADOProjectList -Organization $sourceOrg -Token $sourceToken -ApiVersion $apiVersion -StateFilter All) | Where-Object name -eq $sourceProjectName
$sourceProject = Get-ADOProject -Organization $sourceOrg -Token $sourceToken -ProjectId $sourceProjectMeta.id -IncludeCapabilities -ApiVersion $apiVersion
$proc = Invoke-ADOProcessMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg -SourceToken $sourceToken -TargetToken $targetToken -SourceProject $sourceProject -ApiVersion $apiVersion
$targetProcessName = $proc.TargetProcess.name

Invoke-ADOCustomFieldMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg \`
    -SourceToken $sourceToken -TargetToken $targetToken -TargetProcessName $targetProcessName -ApiVersion $apiVersion
# Copies all Custom.* fields and ensures tracking field Custom.SourceWorkitemId exists.

## PARAMETERS

### -SourceOrganization
The name of the source Azure DevOps organization.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetOrganization
The name of the target Azure DevOps organization.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SourceToken
The authentication token for accessing the source Azure DevOps organization.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetToken
The authentication token for accessing the target Azure DevOps organization.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetProcessName
The name of the target process in the target organization.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiVersion
The version of the Azure DevOps REST API to use.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
This function is part of the ADO Tools module and adheres to the conventions used in the module for logging, error handling, and API interaction.
Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS
