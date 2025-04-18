
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
        
    .PARAMETER CodebasePath
        The path to the codebase to be indexed and reviewed.
        
    .PARAMETER IndexPath
        The path where the indexed codebase will be stored as a JSON file.
        
    .PARAMETER UserQuery
        The query or instructions for Azure OpenAI to perform the code review.
        
    .PARAMETER Filenames
        (Optional) A list of specific filenames to filter the search results.
        
    .PARAMETER ExcludedFolders
        (Optional) A list of folder names to exclude from indexing.
        
    .PARAMETER FileExtensions
        (Optional) A list of file extensions to include in the indexing process.
        
    .EXAMPLE
        # Define the required parameters
        $openaiEndpoint = "https://YourAzureOpenApiEndpoint"
        $openaiApiKey = "your-api-key"
        $codebasePath = "C:\Projects\MyCodebase"
        $userQuery = "Analyze the code for bugs and improvements."
        $filenames = @("example1.al", "example2.al")
        
        # Call the function
        Invoke-ADOAzureOpenAI -OpenAIEndpoint $openaiEndpoint `
        -OpenAIApiKey $openaiApiKey `
        -CodebasePath $codebasePath `
        -UserQuery $userQuery `
        -Filenames $filenames
        
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
        [Parameter(Mandatory = $true)]
        [string]$CodebasePath,
        [string]$IndexPath = "c:\temp\codebase_index.json",
        [string]$UserQuery,

        [Parameter(Mandatory = $true)]
        [array]$Filenames = @(),

        [array]$ExcludedFolders = @(".git", "node_modules", ".vscode"),
        [array]$FileExtensions = @(".al", ".json", ".xml", ".txt")
    )

    try {
        # Step 1: Index the codebase
        Write-PSFMessage -Level Host -Message "Indexing the codebase at path: $CodebasePath"
        $index = @()

        If(-not (Test-Path $IndexPath)) {
            $null = New-Item -Path $IndexPath -ItemType File -Force
        }

        Get-ChildItem -Path $CodebasePath -Recurse -File | Where-Object {
            ($FileExtensions -contains $_.Extension) -and
            ($ExcludedFolders -notcontains $_.DirectoryName.Split('\')[-1])
        } | ForEach-Object {
            $filePath = $_.FullName
            $content = Get-Content -Path $filePath -Raw
            $index += @{
                FilePath = "$filePath"
                Content = $content
            }
        }

        $index | ConvertTo-Json -Depth 10 | Set-Content -Path $IndexPath
        Write-PSFMessage -Level Host -Message "Indexing completed. Output saved to: $IndexPath"

        # Step 2: Search the codebase
        Write-PSFMessage -Level Host -Message "Searching the codebase for relevant files."
        $index = Get-Content -Path $IndexPath | ConvertFrom-Json
        $context = @()

        foreach ($file in $index) {
            if ($file.Content -match [regex]::Escape("")) {
                $context += @{
                    FilePath = $file.FilePath
                    Snippet = $file.Content -replace "(?s).{0,50}" + [regex]::Escape("") + ".{0,50}", "...$&..."
                }
            }
        }

        Write-PSFMessage -Level Host -Message "Filtering results based on provided filenames."
        $context = $context | Where-Object {
            $filePath = $_.FilePath
            $Filenames | ForEach-Object { $filePath -like "*$_" } | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
        }

        Write-PSFMessage -Level Host -Message "Search completed. Found $($context.Count) matching files."

        # Step 3: Query Azure OpenAI
        Write-PSFMessage -Level Host -Message "Sending request to Azure OpenAI for code review."
        $fullPrompt = "You are an assistant that helps with code suggestions. Here is the context:\n"
        foreach ($snippet in $context) {
            $fullPrompt += "File: $($snippet.FilePath)\nCode:\n$($snippet.Snippet)\n\n"
        }
        $fullPrompt += "User Query: $UserQuery"

        $body = @{
            messages = @(
                @{ role = "system"; content = "You are a helpful assistant for code suggestions." },
                @{ role = "user"; content = $fullPrompt }
            )
        } | ConvertTo-Json -Depth 10

        $headers = @{
            "Content-Type" = "application/json"
            "api-key" = $OpenAIApiKey
        }

        $response = Invoke-RestMethod -Uri $OpenAIEndpoint -Method Post -Headers $headers -Body $body
        Write-PSFMessage -Level Host -Message "Azure OpenAI response received."

        # Output the response
        return $response.choices[0].message.content
    } catch {
        Write-PSFMessage -Level Error -Message "An error occurred: $($_.Exception.Message)"
        throw
    }
}