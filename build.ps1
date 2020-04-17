<#
  .SYNOPSIS
    Puppetize a PowerShell module with DSC resources
  .DESCRIPTION
    This script builds a Puppet Module which wraps and calls PowerShell DSC resources
    via the Puppet resource_api. This module:

    - Includes a base resource_api provider which relies on ruby-pwsh and knows how to invoke DSC resources
    - Includes a type for each DSC resource, pulling in the appropriate metadata including help, default value
      and mandatory status, as well as whether or not it includes an embedded mof.
    - Allows for the tracking of changes on a property-by-property basis while using DSC and Puppet together
  .PARAMETER PowerShellModuleName
    The name of the PowerShell module on the gallery which has DSC resources you want to Puppetize
  .PARAMETER PowerShellModuleVersion
    The version of the PowerShell module on the gallery which has DSC resources you want to Puppetize.
    If left blank, will default to latest available.
  .PARAMETER PuppetModuleName
    The name of the Puppet module for the wrapper; if not specified, will default to the downcased name of
    the module to adhere to Puppet naming conventions.
  .EXAMPLE
    .\build.ps1 -PowerShellModuleName PowerShellGet -PowerShellModuleVersion 2.2.3
  .NOTES
    For right now, we require the powershell-yaml module and the PDK
#>
[CmdletBinding()]
param(
  $PuppetModuleName,
  $PuppetModuleAuthor,
  $PowerShellModuleName = 'PowerShellGet',
  $PowerShellModuleVersion
)

If ($null -eq $PuppetModuleName) { $PuppetModuleName = $PowerShellModuleName.tolower() }

Import-Module "$PSScriptRoot/src/puppet.dsc.psd1" -Force

$importDir   = Join-Path $PSScriptRoot 'import'
$moduleDir   = Join-Path $importDir $PuppetModuleName

# create new pdk module
Initialize-PuppetModule -OutputFolderPath $importDir -PuppetModuleName $PuppetModuleName -verbose

$downloadedDscResources    = Join-Path $importDir "$PuppetModuleName/lib/puppet_x/dsc_resources"
Add-DscResourceModule -Name $PowerShellModuleName -Path $downloadedDscResources -RequiredVersion $PowerShellModuleVersion

# Update the Puppet module metadata
$MetadataParameters = @{
  PuppetModuleFolderPath = $moduleDir
  PowerShellModuleManifestPath = (Resolve-Path "$downloadedDscResources/$PowerShellModuleName/$PowerShellModuleName.psd1")
  PuppetModuleAuthor = $PuppetModuleAuthor
}
Update-PuppetModuleMetadata @MetadataParameters

# Update the Puppet module test fixtures
Update-PuppetModuleFixture -PuppetModuleFolderPath $moduleDir

# build puppet types from dsc resources
[string]$puppetTypeDir              = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'type')
[string]$puppetProviderDir          = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'provider')


$oldPsModulePath  = $env:PSModulePath
$env:PSModulePath = "$($downloadedDscResources);"
$Resources = Get-DscResource -Module $PowerShellModuleName | ConvertTo-PuppetResourceApi

# Files are written using UTF8, but newlines will need to addressed
foreach($Resource in $Resources){
  if(-not(Test-Path $puppetTypeDir)){
    New-Item -Path $puppetTypeDir -ItemType Directory -Force | Out-Null
  }
  [string]$puppetTypeFileName = Join-Path -Path $puppetTypeDir -ChildPath $Resource.RubyFileName
  [IO.File]::WriteAllLines($puppetTypeFileName, $Resource.Type)

  [string]$ProviderDirectoryPath  = Join-Path -Path $puppetProviderDir     -ChildPath $Resource.Name
  [string]$ProviderFilePath       = Join-Path -Path $ProviderDirectoryPath -ChildPath $Resource.RubyFileName
  if(-not(Test-Path $ProviderDirectoryPath)){
    New-Item -Path $ProviderDirectoryPath -ItemType Directory -Force | Out-Null
  }
  [IO.File]::WriteAllLines($ProviderFilePath, $Resource.Provider)
}
$env:PSModulePath = $oldPsModulePath
