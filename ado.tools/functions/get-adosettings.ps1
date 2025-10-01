
<#
    .SYNOPSIS
        Get the ADO configuration details
        
    .DESCRIPTION
        Get the ADO configuration details from the configuration store
        
        All settings retrieved from this cmdlets is to be considered the default parameter values across the different cmdlets
        
    .PARAMETER SettingsJsonString
        String contains settings JSON
        
    .PARAMETER SettingsJsonPath
        String contains path to the settings.json
        
    .PARAMETER OutputAsHashtable
        Instruct the cmdlet to return a hashtable object
        
    .EXAMPLE
        PS C:\> Get-ADOSettings
        
        This will output the current ADO configuration.
        The object returned will be a PSCustomObject.
        
    .EXAMPLE
        PS C:\> Get-ADOSettings -OutputAsHashtable
        
        This will output the current ADO configuration.
        The object returned will be a Hashtable.
        
    .LINK
        Set-ADOSettings
        
    .NOTES
        Tags: Environment, Url, Config, Configuration, LCS, Upload, ClientId
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
        
#>

function Get-ADOSettings {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
    param (
        [string] $SettingsJsonString,
        [string] $SettingsJsonPath,
        [switch] $OutputAsHashtable
    )
    begin{
        Invoke-TimeSignal -Start   
        $helperPath = Join-Path -Path $($Script:ModuleRoot) -ChildPath "\internal\scripts\helpers.ps1" -Resolve
        . ($helperPath)    
        $res = [Ordered]@{}

        if((-not ($SettingsJsonString -eq "")) -and (-not ($SettingsJsonPath -eq "")))
        {
            throw "Both settings parameters should not be provided. Please provide only one of them."
        }

        if(-not ($SettingsJsonString -eq ""))
        {
            $tmpSettingsFilePath = "C:\temp\settings.json"
            $null = Test-PathExists -Path "C:\temp\" -Type Container -Create
            $null = Set-Content $tmpSettingsFilePath $SettingsJsonString -Force -PassThru
            $null = Set-ADOSettings -SettingsFilePath $tmpSettingsFilePath
        }

        if(-not ($SettingsJsonPath -eq ""))
        {
            $null = Set-ADOSettings -SettingsFilePath $SettingsJsonPath
        }
    }
    process{         

        foreach ($config in Get-PSFConfig -FullName "ado.tools.settings.*") {
            $propertyName = $config.FullName.ToString().Replace("ado.tools.settings.", "")
            $res.$propertyName = $config.Value
        }
        if($OutputAsHashtable) {
            $res
        } else {
            [PSCustomObject]$res
        }   
       
    }
    end{
        Invoke-TimeSignal -End
    }

}