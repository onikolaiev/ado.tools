---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Get-ADOProjectList

## SYNOPSIS
Retrieves a list of projects in the Azure DevOps organization that the authenticated user has access to.

## SYNTAX

```
Get-ADOProjectList [-Organization] <String> [-Token] <String> [[-StateFilter] <ProjectState>] [[-Top] <Int32>]
 [[-Skip] <Int32>] [[-ContinuationToken] <Int32>] [-GetDefaultTeamImageUrl] [[-ApiVersion] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function uses the \`Invoke-ADOApiRequest\` function to call the Azure DevOps REST API and retrieve a list of projects.
It supports optional parameters such as state filter, pagination, and default team image URL.

## EXAMPLES

### EXAMPLE 1
```
Get-ADOProjectList -Organization "fabrikam" -Token "my-token"
```

Retrieves all projects in the specified organization.

### EXAMPLE 2
```
Get-ADOProjectList -Organization "fabrikam" -Token "my-token" -StateFilter "WellFormed" -Top 10
```

Retrieves the first 10 well-formed projects in the specified organization.

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

### -StateFilter
Filter on team projects in a specific state (e.g., WellFormed, Deleted, All).
Default is WellFormed.

```yaml
Type: ProjectState
Parameter Sets: (All)
Aliases:
Accepted values: All, CreatePending, Deleted, Deleting, New, Unchanged, WellFormed

Required: False
Position: 3
Default value: All
Accept pipeline input: False
Accept wildcard characters: False
```

### -Top
The maximum number of projects to return.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Skip
The number of projects to skip.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ContinuationToken
Pointer that shows how many projects have already been fetched.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -GetDefaultTeamImageUrl
Whether to include the default team image URL in the response.

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
The version of the Azure DevOps REST API to use.
Default is set globally.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
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
The function will return the project list in a structured format.

Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS
