<#
This is an example configuration file

By default, it is enough to have a single one of them,
however if you have enough configuration settings to justify having multiple copies of it,
feel totally free to split them into multiple files.
#>

<#
# Example Configuration
Set-PSFConfig -Module 'ado.tools' -Name 'Example.Setting' -Value 10 -Initialize -Validation 'integer' -Handler { } -Description "Example configuration setting. Your module can then use the setting using 'Get-PSFConfigValue'"
#>

Set-PSFConfig -Module 'ado.tools' -Name 'Import.DoDotSource' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging."
Set-PSFConfig -Module 'ado.tools' -Name 'Import.IndividualFiles' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments."

# Migration feature toggles (public orchestration will consult these flags)
Set-PSFConfig -Module 'ado.tools' -Name 'settings.Migration.Process'           -Value $true  -Initialize -Validation 'bool' -Description 'Enable process (process template) migration.'
Set-PSFConfig -Module 'ado.tools' -Name 'settings.Migration.WorkItems'        -Value $true  -Initialize -Validation 'bool' -Description 'Enable work item data migration.'
Set-PSFConfig -Module 'ado.tools' -Name 'settings.Migration.Attachments'     -Value $true  -Initialize -Validation 'bool' -Description 'Enable attachment migration.'
Set-PSFConfig -Module 'ado.tools' -Name 'settings.Migration.Comments'     -Value $true  -Initialize -Validation 'bool' -Description 'Enable comments migration.'
Set-PSFConfig -Module 'ado.tools' -Name 'settings.Migration.Users'     -Value $true  -Initialize -Validation 'bool' -Description 'Enable custom field migration.'
Set-PSFConfig -Module 'ado.tools' -Name 'settings.Migration.ClassificationNodes' -Value $true -Initialize -Validation 'bool' -Description 'Enable classification nodes (Areas and Iterations) migration.'
Set-PSFConfig -Module 'ado.tools' -Name 'settings.Migration.Teams' -Value $true -Initialize -Validation 'bool' -Description 'Enable teams migration.'
