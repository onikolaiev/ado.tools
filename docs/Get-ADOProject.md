---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Get-ADOProject

## SYNOPSIS
Retrieves a specific project in the Azure DevOps organization by its ID or name.

## SYNTAX

```
Get-ADOProject [-Organization] <String> [-Token] <String> [-ProjectId] <String> [-IncludeCapabilities]
 [-IncludeHistory] [[-ApiVersion] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function uses the \`Invoke-ADOApiRequest\` function to call the Azure DevOps REST API and retrieve a specific project.
It supports optional parameters to include capabilities and history in the response.

## EXAMPLES

### EXAMPLE 1
```
Get-ADOProject -Organization "fabrikam" -Token "my-token" -ProjectId "6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c"
```

Retrieves the project with the specified ID.

### EXAMPLE 2
```
Get-ADOProject -Organization "fabrikam" -Token "my-token" -ProjectId "MyProject" -IncludeCapabilities -IncludeHistory
```

Retrieves the project with the specified name, including capabilities and history.

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
The ID or name of the project to retrieve.

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

### -IncludeCapabilities
Whether to include capabilities (such as source control) in the team project result.
Default is $false.

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

### -IncludeHistory
Whether to search within renamed projects (that had such name in the past).
Default is $false.

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

### -ApiVersion
{{ Fill ApiVersion Description }}

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
The project ID can be either the GUID or the name of the project.
The function will return the project details in a structured format.

Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS
