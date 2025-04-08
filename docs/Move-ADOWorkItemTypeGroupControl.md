---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Move-ADOWorkItemTypeGroupControl

## SYNOPSIS
Moves a control to a specified group.

## SYNTAX

```
Move-ADOWorkItemTypeGroupControl [-Organization] <String> [-Token] <String> [-ProcessId] <String>
 [-WitRefName] <String> [-GroupId] <String> [-ControlId] <String> [-Body] <String>
 [[-RemoveFromGroupId] <String>] [[-ApiVersion] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function uses the \`Invoke-ADOApiRequest\` function to call the Azure DevOps REST API and move a control to a new group in a specified work item type.

## EXAMPLES

### EXAMPLE 1
```
$body = @"
{
    "label": "",
    "readonly": false,
    "id": "c1681eea-cf9e-4a32-aee9-83e97fde894a",
    "isContribution": true,
    "visible": true,
    "contribution": {
        "contributionId": "ms-devlabs.toggle-control.toggle-control-contribution",
        "inputs": {
            "FieldName": "System.BoardColumnDone",
            "TrueLabel": "new value"
        }
    },
    "order": 0
}
"@
```

Move-ADOWorkItemTypeGroupControl -Organization "fabrikam" -Token "my-token" -ProcessId "906c7065-2a04-4f61-aac1-b5da9cef040b" -WitRefName "MyNewAgileProcess.ChangeRequest" -GroupId "new-group-id" -ControlId "control-id" -Body $body -RemoveFromGroupId "old-group-id"

Moves the specified control to a new group.

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

### -GroupId
The ID of the group to move the control to.

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

### -ControlId
The ID of the control to move.

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

### -Body
The JSON string containing the properties for the control to move.

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

### -RemoveFromGroupId
Optional parameter specifying the group ID to remove the control from.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
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
Position: 9
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
