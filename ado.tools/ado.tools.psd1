#
# Module manifest for module 'ado.tools'
#
# Generated by: Oleksandr Nikolaiev
#
# Generated on: 4/18/2025
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'ado.tools.psm1'

# Version number of this module.
ModuleVersion = '1.0.43'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '1dda8cec-ccbd-48e0-9591-daf7f8b5adb3'

# Author of this module
Author = 'Oleksandr Nikolaiev'

# Company or vendor of this module
CompanyName = 'Ciellos INC.'

# Copyright statement for this module
Copyright = '2025 (c) Oleksandr Nikolaiev. All rights reserved.'

# Description of the functionality provided by this module
Description = 'This module contains set of the Azure DevOps cmdlets for managing work item types, processes,  picklists, etc.. It is designed to be used with the Azure DevOps REST API and provides a convenient way to interact with Azure DevOps services from PowerShell.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.0'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(@{ModuleName = 'PSFramework'; ModuleVersion = '1.12.346'; }, 
               @{ModuleName = 'ado.core'; ModuleVersion = '1.0.3'; })

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = 'xml\ado.tools.Format.ps1xml'

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Invoke-ADOProjectMigration', 'Invoke-ADOAzureOpenAI'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
# VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'd365fsc','AzureDevOps','D365','ADO','fscps','ascii','Ciellos','DevOps'

        # A URL to the license for this module.
        LicenseUri = 'https://opensource.org/license/mit'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/onikolaiev/ado.tools'

        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/onikolaiev/ado.tools/master/images/ado-tools-logo.png'

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        ExternalModuleDependencies = @('PSDiagnostics')

    } # End of PSData hashtable

 } # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

