
<#
    .SYNOPSIS
        Set the ADO configuration details
        
    .DESCRIPTION
        Set the ADO configuration details from the configuration store
        
        All settings retrieved from this cmdlets is to be considered the default parameter values across the different cmdlets
        
    .PARAMETER SettingsJsonString
        String contains JSON with custom settings
        
    .PARAMETER SettingsFilePath
        Set path to the settings.json file
        
    .EXAMPLE
        PS C:\> Set-ADOSettings -SettingsFilePath "c:\temp\settings.json"
        
        This will output the current ADO configuration.
        The object returned will be a Hashtable.
        
    .LINK
        Get-ADOSettings
        
    .NOTES
        Tags: Environment, Url, Config, Configuration, Upload, ClientId, Settings
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
        
#>

function Set-ADOSettings {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [string] $SettingsFilePath,
        [string] $SettingsJsonString
    )
    begin{
        if((-not ($SettingsJsonString -eq "")) -and (-not ($SettingsFilePath -eq "")))
        {
            throw "Both settings parameters cannot be provided. Please provide only one of them."
        }

        if(-not ($SettingsJsonString -eq ""))
        {
            $SettingsFilePath = "C:\temp\settings.json"
            $null = Test-PathExists -Path "C:\temp\" -Type Container -Create
            $null = Set-Content $SettingsFilePath $SettingsJsonString -Force -PassThru
        }

        
        function MergeCustomObjectIntoOrderedDictionary {
            Param(
                [System.Collections.Specialized.OrderedDictionary] $dst,
                [PSCustomObject] $src
            )
        
            # Add missing properties in OrderedDictionary

            $src.PSObject.Properties.GetEnumerator() | ForEach-Object {
                $prop = $_.Name
                $srcProp = $src."$prop"
                $srcPropType = $srcProp.GetType().Name
                if (-not $dst.Contains($prop)) {
                    if ($srcPropType -eq "PSCustomObject") {
                        $dst.Add("$prop", [ordered]@{})
                    }
                    elseif ($srcPropType -eq "Object[]") {
                        $dst.Add("$prop", @())
                    }
                    else {
                        $dst.Add("$prop", $srcProp)
                    }
                }
            }
        
            @($dst.Keys) | ForEach-Object {
                $prop = $_
                if ($src.PSObject.Properties.Name -eq $prop) {
                    $dstProp = $dst."$prop"
                    $srcProp = $src."$prop"
                    $dstPropType = $dstProp.GetType().Name
                    $srcPropType = $srcProp.GetType().Name
                    if($dstPropType -eq 'Int32' -and $srcPropType -eq 'Int64')
                    {
                        $dstPropType = 'Int64'
                    }
                    
                    if ($srcPropType -eq "PSCustomObject" -and $dstPropType -eq "OrderedDictionary") {
                        MergeCustomObjectIntoOrderedDictionary -dst $dst."$prop".Value -src $srcProp
                    }
                    elseif ($dstPropType -ne $srcPropType) {
                        throw "property $prop should be of type $dstPropType, is $srcPropType."
                    }
                    else {
                        if ($srcProp -is [Object[]]) {
                            $srcProp | ForEach-Object {
                                $srcElm = $_
                                $srcElmType = $srcElm.GetType().Name
                                if ($srcElmType -eq "PSCustomObject") {
                                    $ht = [ordered]@{}
                                    $srcElm.PSObject.Properties | Sort-Object -Property Name -Culture "iv-iv" | ForEach-Object { $ht[$_.Name] = $_.Value }
                                    $dst."$prop" += @($ht)
                                }
                                else {
                                    $dst."$prop" += $srcElm
                                }
                            }
                        }
                        else {
                            Write-PSFMessage -Level Verbose -Message "Searching ado.tools.settings.*.$prop"
                            $setting = Get-PSFConfig -FullName "ado.tools.settings.*.$prop"
                            Write-PSFMessage -Level Verbose -Message "Found  $setting"
                            if($setting)
                            {
                                Set-PSFConfig -FullName $setting.FullName -Value $srcProp
                            }
                            #$dst."$prop" = $srcProp
                        }
                    }
                }
            }
        }
    }
    process{
        Invoke-TimeSignal -Start    
        $res = Get-ADOSettings -OutputAsHashtable

        $settingsFiles | ForEach-Object {
            $settingsFile = $_
            if($RepositoryRootPath)
            {
                $settingsPath = Join-Path $RepositoryRootPath $settingsFile
            }
            else {
                $settingsPath = $SettingsFilePath
            }
            
            Write-PSFMessage -Level Verbose -Message "Settings file '$settingsFile' - $(If (Test-Path $settingsPath) {"exists. Processing..."} Else {"not exists. Skip."})"
            if (Test-Path $settingsPath) {
                try {
                    $settingsJson = Get-Content $settingsPath -Encoding UTF8 | ConvertFrom-Json
        
                    # check settingsJson.version and do modifications if needed
                    MergeCustomObjectIntoOrderedDictionary -dst $res -src $settingsJson
                }
                catch {
                    Write-PSFMessage -Level Host -Message "Settings file $settingsPath, is wrongly formatted." -Exception $PSItem.Exception
                    Stop-PSFFunction -Message "Stopping because of errors"
                    return
                    throw 
                }
            }
            Write-PSFMessage -Level Verbose -Message "Settings file '$settingsFile' - processed"
        }
        Write-PSFMessage -Level Host  -Message "Settings were updated succesfully."
        Invoke-TimeSignal -End
    }
    end{

    }

}