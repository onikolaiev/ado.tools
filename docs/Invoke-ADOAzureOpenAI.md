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
Invoke-ADOAzureOpenAI [-OpenAIEndpoint] <String> [-OpenAIApiKey] <String> [[-Messages] <Array>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function indexes a codebase, searches for relevant files, and queries Azure OpenAI to perform a detailed code review.
It generates a report based on the provided user query and context extracted from the codebase.

## EXAMPLES

### EXAMPLE 1
```
# Define the required parameters
$openaiEndpoint = "https://YourAzureOpenApiEndpoint"
$openaiApiKey = "your-api-key"
$prompt = "Who are you?"
$messages = @(
    @{ role = "system"; content = "You are a helpful assistant." },
    @{ role = "user"; content = $prompt }
)
```

# Call the function
Invoke-ADOAzureOpenAI -OpenAIEndpoint $openaiEndpoint \`
    -OpenAIApiKey $openaiApiKey \`
    -CodebasePath $codebasePath \`
    -Messages $messages

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

### -Messages
The messages to be sent to Azure OpenAI.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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

### Returns a hashtable containing the response from Azure OpenAI.
### The hashtable includes the following keys:
###     - id
###     - object
###     - created
###     - model
###     - usage
###     - choices
### #Example response
### @"
### {
###     "model": "o1-2024-12-17",
###     "created": 1745923901,
###     "object": "chat.completion",
###     "id": "chatcmpl-BRcqr2gTdJH2EeL63R3jEM5ZVOpUD",
###     "choices": [
###     {
###         "content_filter_results": {
###             "hate": {
###                 "filtered": false,
###                 "severity": "safe"
###             },
###             "self_harm": {
###                 "filtered": false,
###                 "severity": "safe"
###             },
###             "sexual": {
###                 "filtered": false,
###                 "severity": "safe"
###             },
###             "violence": {
###                 "filtered": false,
###                 "severity": "safe"
###             }
###         },
###         "finish_reason": "stop",
###         "index": 0,
###         "logprobs": null,
###         "message": {
###             "content": "I'm ChatGPT, a large language model trained by OpenAI. I'm here to help you with your questions, provide information, and engage in conversation. How can I assist you today?",
###             "refusal": null,
###             "role": "assistant"
###         }
###     }
###     ],
###     "usage": {
###         "completion_tokens": 178,
###         "completion_tokens_details": {
###             "accepted_prediction_tokens": 0,
###             "audio_tokens": 0,
###             "reasoning_tokens": 128,
###             "rejected_prediction_tokens": 0
###         },
###         "prompt_tokens": 20,
###         "prompt_tokens_details": {
###             "audio_tokens": 0,
###             "cached_tokens": 0
###         },
###         "total_tokens": 198
###     }
### }
### "@
## NOTES
This function uses PSFramework for logging and exception handling.

Author: Oleksandr Nikolaiev (@onikolaiev)

## RELATED LINKS
