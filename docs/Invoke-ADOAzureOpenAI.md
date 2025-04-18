---
external help file: ado.tools-help.xml
Module Name: ado.tools
online version:
schema: 2.0.0
---

# Invoke-ADOAzureOpenAI

## SYNOPSIS
Performs a code review of a Microsoft Dynamics 365 Business Central AL codebase using Azure OpenAI.

## SYNTAX

```
Invoke-ADOAzureOpenAI [-OpenAIEndpoint] <String> [-OpenAIApiKey] <String> [-CodebasePath] <String>
 [[-IndexPath] <String>] [[-UserQuery] <String>] [-Filenames] <Array> [[-ExcludedFolders] <Array>]
 [[-FileExtensions] <Array>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function indexes a codebase, searches for relevant files, and queries Azure OpenAI to perform a detailed code review.
It generates a report based on the provided user query and context extracted from the codebase.

## EXAMPLES

### EXAMPLE 1
```
# Define the required parameters
$openaiEndpoint = "https://onopenai.openai.azure.com/openai/deployments/o1/chat/completions?api-version=2024-12-01-preview"
$openaiApiKey = "your-api-key"
$codebasePath = "C:\Projects\MyCodebase"
$indexPath = "C:\Temp\codebase_index.json"
$userQuery = "Analyze the code for bugs and improvements."
$filenames = @("example1.al", "example2.al")
```

# Call the function
Invoke-ADOAzureOpenAI -OpenAIEndpoint $openaiEndpoint \`
                    -OpenAIApiKey $openaiApiKey \`
                    -CodebasePath $codebasePath \`
                    -IndexPath $indexPath \`
                    -UserQuery $userQuery \`
                    -Filenames $filenames

## PARAMETERS

### -OpenAIEndpoint
The Azure OpenAI endpoint URL.

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

### -OpenAIApiKey
The API key for authenticating with Azure OpenAI.

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

### -CodebasePath
The path to the codebase to be indexed and reviewed.

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

### -IndexPath
The path where the indexed codebase will be stored as a JSON file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: C:\temp\codebase_index.json
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserQuery
The query or instructions for Azure OpenAI to perform the code review.

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

### -Filenames
(Optional) A list of specific filenames to filter the search results.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: True
Position: 6
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludedFolders
(Optional) A list of folder names to exclude from indexing.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: @(".git", "node_modules", ".vscode")
Accept pipeline input: False
Accept wildcard characters: False
```

### -FileExtensions
(Optional) A list of file extensions to include in the indexing process.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: @(".al", ".json", ".xml", ".txt")
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
This function uses PSFramework for logging and exception handling.

Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS
