---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Get-ADOWorkItemType

## SYNOPSIS
Retrieves a single work item type in a process.

## SYNTAX

```
Get-ADOWorkItemType [-Organization] <String> [-Token] <String> [-ProcessId] <String> [-WitRefName] <String>
 [[-Expand] <String>] [[-ApiVersion] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function uses the \`Invoke-ADOApiRequest\` function to call the Azure DevOps REST API and retrieve a single work item type in a process.
It supports optional parameters to expand specific properties of the work item type.

## EXAMPLES

### EXAMPLE 1
```
Get-ADOWorkItemType -Organization "fabrikam" -Token "my-token" -ProcessId "c5ef8a1b-4f0d-48ce-96c4-20e62993c218" -WitRefName "MyNewAgileProcess.ChangeRequest"
```

Retrieves the specified work item type in the given process.

### EXAMPLE 2
```
Get-ADOWorkItemType -Organization "fabrikam" -Token "my-token" -ProcessId "c5ef8a1b-4f0d-48ce-96c4-20e62993c218" -WitRefName "MyNewAgileProcess.ChangeRequest" -Expand "layout"
```

Retrieves the specified work item type with the layout property expanded.

## PARAMETERS

### -Organization
The name of the Azure DevOps organization.

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

### -Token
The authentication token for accessing Azure DevOps.

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

### -ProcessId
The ID of the process.

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

### -WitRefName
The reference name of the work item type.

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

### -Expand
Optional parameter to expand specific properties of the work item type (e.g., behaviors, layout, states).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiVersion
The version of the Azure DevOps REST API to use.
Default is "7.1".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: $Script:ADOApiVersion
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
This function follows PSFramework best practices for logging and error handling.

Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS
