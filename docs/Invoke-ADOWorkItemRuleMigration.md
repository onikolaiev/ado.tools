---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Invoke-ADOWorkItemRuleMigration

## SYNOPSIS
Migrates rules for inherited WITs.

## SYNTAX

```
Invoke-ADOWorkItemRuleMigration [-SourceOrganization] <String> [-TargetOrganization] <String>
 [-SourceToken] <String> [-TargetToken] <String> [-SourceProcess] <PSObject> [-TargetProcess] <PSObject>
 [-SourceWitList] <IEnumerable> [-TargetWitList] <IEnumerable> [-ApiVersion] <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Migrates rules assigned to each inherited WIT in process.
This includes copying rules from the source WITs to the target WITs, ensuring that all customizations are preserved.

## EXAMPLES

### EXAMPLE 1
```
$apiVersion = '7.1'
$sourceOrg  = 'srcOrg'
$targetOrg  = 'tgtOrg'
$sourceToken = 'pat-src'
$targetToken = 'pat-tgt'
$sourceProjectName = 'Sample'
$sourceProjectMeta = (Get-ADOProjectList -Organization $sourceOrg -Token $sourceToken -ApiVersion $apiVersion -StateFilter All) | Where-Object name -eq $sourceProjectName
$sourceProject = Get-ADOProject -Organization $sourceOrg -Token $sourceToken -ProjectId $sourceProjectMeta.id -IncludeCapabilities -ApiVersion $apiVersion
$proc = Invoke-ADOProcessMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg -SourceToken $sourceToken -TargetToken $targetToken -SourceProject $sourceProject -ApiVersion $apiVersion
$witResult = Invoke-ADOWorkItemTypeMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg -SourceToken $sourceToken -TargetToken $targetToken -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess -ApiVersion $apiVersion
```

Invoke-ADOWorkItemRuleMigration -SourceOrganization $sourceOrg -TargetOrganization $targetOrg \`
    -SourceToken $sourceToken -TargetToken $targetToken -SourceProcess $proc.SourceProcess -TargetProcess $proc.TargetProcess \`
    -SourceWitList $witResult.SourceList -TargetWitList $witResult.TargetList -ApiVersion $apiVersion
# Migrates non-system rules for each inherited WIT.

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

### -SourceProcess
The source process object containing details about the process to migrate.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetProcess
The target process object containing details about the process to migrate to.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SourceWitList
The list of source work item types to migrate.

```yaml
Type: IEnumerable
Parameter Sets: (All)
Aliases:

Required: True
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetWitList
The list of target work item types to migrate to.

```yaml
Type: IEnumerable
Parameter Sets: (All)
Aliases:

Required: True
Position: 8
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
Position: 9
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
