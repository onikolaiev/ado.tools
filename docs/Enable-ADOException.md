﻿---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Enable-ADOException

## SYNOPSIS
Enable exceptions to be thrown

## SYNTAX

```
Enable-ADOException [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Change the default exception behavior of the module to support throwing exceptions

Useful when the module is used in an automated fashion, like inside Azure DevOps pipelines and large PowerShell scripts

## EXAMPLES

### EXAMPLE 1
```
Enable-ADOException
```

This will for the rest of the current PowerShell session make sure that exceptions will be thrown.

## PARAMETERS

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
Tags: Exception, Exceptions, Warning, Warnings

Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS

[Disable-ADOException]()

