﻿$excludeCommands = @(
    , 'Test-FSCPSCommand'
    , 'Test-PathExists'
)

$excludeParameters = @(
    'EnableException'
    , 'TrustedConnection'
    , 'Force'
    , 'Temporary'
    , 'OutputCommandOnly'
    , 'ShowOriginalProgress'
    , 'Rebuild'
    , 'FailOnErrorMessage'
)

$commandsRaw = Get-Command -Module ado.tools

if ($excludeCommands.Count -gt 0) {
    $commands = $commandsRaw | Select-String -Pattern $excludeCommands -SimpleMatch -NotMatch

}
else {
    $commands = $commandsRaw
}

foreach ( $commandName in $commands) {
    if ($commandName -notlike "*fscps*") {
        continue
    }
    # command to be tested

    # get all examples from the help
    $examples = Get-Help $commandName -Examples

    $parameters = (Get-Help $commandName -Full).parameters

    # make a describe block that will contain tests for this
    Describe "Parameters without default values from $commandName" {
        
        foreach ($parm in $parameters.parameter) {            
            if ($parm.defaultValue -ne "False") { continue }
            if ($parm.parameterValue -eq "SwitchParameter" -and $parm.defaultValue -ne "" ) { continue }
            $parmName = $parm.name
            
            if ($parmName -in $excludeParameters) { continue }
            
            
            $res = $false
            
            foreach ($exampleObject in $examples.Examples.Example) {
                if ($res) { continue }

                $example = $exampleObject.Code -replace "`n.*" -replace "PS C:\>"

                $res = $example -match "-$parmName( *|\:)"
            }
            It "$parmName is present in an example" {
                $res | Should -BeTrue
            }
        }
    }
}
