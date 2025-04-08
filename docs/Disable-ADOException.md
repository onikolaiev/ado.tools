---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Disable-ADOException

## SYNOPSIS
Disables throwing of exceptions

## SYNTAX

```
Disable-ADOException [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Restore the default exception behavior of the module to not support throwing exceptions

Useful when the default behavior was changed with Enable-ADOException and the default behavior should be restored

## EXAMPLES

### EXAMPLE 1
```
Disable-ADOException
```

This will restore the default behavior of the module to not support throwing exceptions.

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

[Enable-ADOException]()

