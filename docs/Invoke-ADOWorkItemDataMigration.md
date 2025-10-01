---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Invoke-ADOWorkItemDataMigration

## SYNOPSIS
Migrates work items from source project into target project using tracking field.

## SYNTAX

```
Invoke-ADOWorkItemDataMigration [-SourceOrganization] <String> [-TargetOrganization] <String>
 [-SourceToken] <String> [-TargetToken] <String> [-SourceProjectName] <String> [-TargetProjectName] <String>
 [-ApiVersion] <String> [[-MigrateAttachments] <Boolean>] [[-MigrateComments] <Boolean>]
 [[-RewriteInlineAttachmentLinks] <Boolean>] [[-DownloadInlineAttachments] <Boolean>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function migrates work items from a source Azure DevOps project to a target Azure DevOps project.
It uses a tracking field to associate work items in the source project with their counterparts in the target project.

## EXAMPLES

### EXAMPLE 1
```
$apiVersion = '7.1'
$sourceOrg  = 'srcOrg'
$targetOrg  = 'tgtOrg'
$sourceToken = 'pat-src'
$targetToken = 'pat-tgt'
$sourceProjectName = 'Sample'
$targetProjectName = 'MigratedProject'
```

Invoke-ADOWorkItemDataMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg \`
    -SourceToken $sourceToken -TargetToken $targetToken \`
    -SourceProjectName $sourceProjectName -TargetProjectName $targetProjectName -ApiVersion $apiVersion
# Migrates work items not yet copied (no tracking field value present in target).

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

### -SourceProjectName
The name of the source Azure DevOps project.

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

### -TargetProjectName
The name of the target Azure DevOps project.

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

### -ApiVersion
The version of the Azure DevOps REST API to use.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MigrateAttachments
When $true (default) downloads each source work item's attachment (relations rel='AttachedFile') and re-uploads them to the target, adding corresponding relations while avoiding duplicates by filename.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -MigrateComments
When $true (default) migrates work item comments (skipping duplicates by exact text, adding provenance header).

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -RewriteInlineAttachmentLinks
When $true (default) rewrites attachment URLs found inside Description and comments to the newly uploaded target attachment URLs (uses attachment GUID mapping).

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -DownloadInlineAttachments
When $true (default) and together with RewriteInlineAttachmentLinks, any inline-only attachment URLs (GUIDs not present in relations) are downloaded from source and uploaded to target before rewriting.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: True
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
