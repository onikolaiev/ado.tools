
<#
    .SYNOPSIS
        Performs a code review of a Microsoft Dynamics 365 Business Central AL codebase using Azure OpenAI.
        
    .DESCRIPTION
        This function indexes a codebase, searches for relevant files, and queries Azure OpenAI to perform a detailed code review.
        It generates a report based on the provided user query and context extracted from the codebase.
        
    .PARAMETER OpenAIEndpoint
        The Azure OpenAI endpoint URL.
        
    .PARAMETER OpenAIApiKey
        The API key for authenticating with Azure OpenAI.
        
    .PARAMETER Messages
        The messages to be sent to Azure OpenAI.
        
    .EXAMPLE
        # Define the required parameters
        $openaiEndpoint = "https://YourAzureOpenApiEndpoint"
        $openaiApiKey = "your-api-key"
        $prompt = "Who are you?"
        $messages = @(
            @{ role = "system"; content = "You are a helpful assistant." },
            @{ role = "user"; content = $prompt }
        )
        
        
        # Call the function
        Invoke-ADOAzureOpenAI -OpenAIEndpoint $openaiEndpoint `
            -OpenAIApiKey $openaiApiKey `
            -CodebasePath $codebasePath `
            -Messages $messages
        
    .OUTPUTS
        Returns a hashtable containing the response from Azure OpenAI.
        The hashtable includes the following keys:
            - id
            - object
            - created
            - model
            - usage
            - choices
        
        
        #Example response
        @"
        {
            "model": "o1-2024-12-17",
            "created": 1745923901,
            "object": "chat.completion",
            "id": "chatcmpl-BRcqr2gTdJH2EeL63R3jEM5ZVOpUD",
            "choices": [
            {
                "content_filter_results": {
                    "hate": {
                        "filtered": false,
                        "severity": "safe"
                    },
                    "self_harm": {
                        "filtered": false,
                        "severity": "safe"
                    },
                    "sexual": {
                        "filtered": false,
                        "severity": "safe"
                    },
                    "violence": {
                        "filtered": false,
                        "severity": "safe"
                    }
                },
                "finish_reason": "stop",
                "index": 0,
                "logprobs": null,
                "message": {
                    "content": "I’m ChatGPT, a large language model trained by OpenAI. I’m here to help you with your questions, provide information, and engage in conversation. How can I assist you today?",
                    "refusal": null,
                    "role": "assistant"
                }
            }
            ],
            "usage": {
                "completion_tokens": 178,
                "completion_tokens_details": {
                    "accepted_prediction_tokens": 0,
                    "audio_tokens": 0,
                    "reasoning_tokens": 128,
                    "rejected_prediction_tokens": 0
                },
                "prompt_tokens": 20,
                "prompt_tokens_details": {
                    "audio_tokens": 0,
                    "cached_tokens": 0
                },
                "total_tokens": 198
            }
        }
        "@
        
        
    .NOTES
        This function uses PSFramework for logging and exception handling.
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
#>

function Invoke-ADOAzureOpenAI {
    param (
        [Parameter(Mandatory = $true)]
        [string]$OpenAIEndpoint,
        [Parameter(Mandatory = $true)]
        [string]$OpenAIApiKey,
        [Array]$Messages
    )
    begin{       
        $ErrorActionPreference = "Stop"
        Invoke-TimeSignal -Start
        Write-PSFMessage -Level Verbose -Message "Starting Azure OpenAI request."
        
        # Validate messages array
        if (-not $Messages -or $Messages.Count -eq 0) {
            throw "The Messages parameter cannot be null or empty."
        }

        $body = @{
            messages = $Messages
        } | ConvertTo-Json -Depth 10

        $headers = @{
            "Content-Type" = "application/json"
            "api-key" = $OpenAIApiKey
        }
    }
    process{
        if (Test-PSFFunctionInterrupt) { return }

        try {
            $response = Invoke-RestMethod -Uri $OpenAIEndpoint -Method Post -Headers $headers -Body $body
            Write-PSFMessage -Level Verbose -Message "Azure OpenAI response received."
    
            # Output the response
            return $response | Select-PSFObject *

        } catch {
            Write-PSFMessage -Level Error -Message "An error occurred: $($_.Exception.Message)"
            throw
        }
    }
    end{
        # Log the end of the operation
        Write-PSFMessage -Level Verbose -Message "Request completed."
        Invoke-TimeSignal -End
    }
}