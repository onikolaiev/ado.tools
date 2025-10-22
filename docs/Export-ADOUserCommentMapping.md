---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Export-ADOUserCommentMapping

## SYNOPSIS
Exports a JSON template mapping of distinct source comment authors to target users for later migration.

## SYNTAX

```
Export-ADOUserCommentMapping [-Organization] <String> [-ProjectName] <String> [-Token] <String>
 [[-ApiVersion] <String>] [[-OutputPath] <String>] [-Force] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Scans all work item comments in a source Azure DevOps project, collects distinct author email addresses (unique case-insensitive),
and produces a JSON file with entries:
    - sourceEmail : the detected author (from comment createdBy uniqueName or email)
    - targetEmail : initially empty (to be manually filled before running full migration)
    - targetPat   : initially empty (optional per-user PAT if needed during migration)
A final node named '@default_user' is appended to serve as fallback mapping when a source user is not explicitly mapped.

The resulting JSON array can be edited and then supplied to future migration logic to impersonate or attribute comments
according to the mapping (functionality to consume this map is implemented separately).

## EXAMPLES

### EXAMPLE 1
```
Export-ADOUserCommentMapping -Organization org -ProjectName Sample -Token $pat -OutputPath C:\temp\comment-map.json
```

Exports mapping JSON template to C:\temp\comment-map.json

### EXAMPLE 2
```
Export-ADOUserCommentMapping -Organization org -ProjectName Sample -Token $pat -Verbose
```

Writes mapping into current directory as ado.commentUserMapping.json

## PARAMETERS

### -Organization
Source Azure DevOps organization name.

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

### -ProjectName
Source Azure DevOps project name.

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

### -Token
Personal Access Token with read access to Work Items & Comments.

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

### -ApiVersion
API version to use (defaults to module default if not provided).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: $Script:ADOApiVersion
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
Destination path for JSON file.
If only a directory is provided, default filename 'ado.commentUserMapping.json' is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: (Join-Path (Get-Location) 'ado.commentUserMapping.json')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Overwrite existing output file if present.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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
Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS
