---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Set-ADOProjectProperties

## SYNOPSIS
Create, update, or delete team project properties in Azure DevOps.

## SYNTAX

```
Set-ADOProjectProperties [-Organization] <String> [-Token] <String> [-ProjectId] <String> [-Body] <String>
 [[-ApiVersion] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function uses the \`Invoke-ADOApiRequest\` function to call the Azure DevOps REST API and perform operations on team project properties.
It supports operations such as add, remove, replace, and more using JSON Patch.

## EXAMPLES

### EXAMPLE 1
```
$body = @"
[
    {
        "op": "add",
        "path": "/Alias",
        "value": "Fabrikam"
    }
]
"@
```

Set-ADOProjectProperties -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c" -Body $body

Creates or updates the "Alias" property for the specified project.

### EXAMPLE 2
```
$body = @"
[
    {
        "op": "remove",
        "path": "/Alias"
    }
]
"@
```

Set-ADOProjectProperties -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c" -Body $body

Deletes the "Alias" property for the specified project.

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

### -ProjectId
The ID of the project to update properties for.

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

### -Body
The JSON Patch document as a string, specifying the operations to perform on the project properties.

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

### -ApiVersion
The version of the Azure DevOps REST API to use.
Default is "7.1-preview.1".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
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
