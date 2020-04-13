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
  $PowerShellModuleName = 'PowerShellGet',
  $PowerShellModuleVersion
)

If ($null -eq $PuppetModuleName) { $PuppetModuleName = $PowerShellModuleName.tolower() }

Import-Module "$PSScriptRoot/src/puppet.dsc.psd1" -Force

$importDir   = Join-Path $PSScriptRoot 'import'
$moduleDir   = Join-Path $importDir $PuppetModuleName

# create new pdk module
if(-not(Test-Path $importDir)){
  mkdir $importDir
}
if(Test-Path $moduleDir){
  Remove-Item -Path $moduleDir -Force -Recurse
}
Push-Location  $importDir
pdk new module --skip-interview --template-url "https://github.com/puppetlabs/pdk-templates" $PuppetModuleName
Pop-Location

# import dsc resources from psgallery
$downloadedDscResources    = Join-Path $importDir "$PuppetModuleName/lib/puppet_x/dsc_resources"
$downloadedDscResourcesTmp = "$($downloadedDscResources)_tmp"

if(-not(Test-Path $downloadedDscResources)){
  if(-not(Test-Path $downloadedDscResources)){
    mkdir $downloadedDscResources
  }
  if(-not(Test-Path $downloadedDscResourcesTmp)){
    mkdir $downloadedDscResourcesTmp
  }
  Save-Module -Name $PowerShellModuleName -Path $downloadedDscResourcesTmp -RequiredVersion $PowerShellModuleVersion
  ForEach ($ModuleFolder in (Get-ChildItem $downloadedDscResourcesTmp)) {
    Move-Item -Path (Get-ChildItem $ModuleFolder.FullName).FullName -Destination "$downloadedDscResources/$($ModuleFolder.Name)"
  }
  Remove-Item $downloadedDscResourcesTmp -Recurse
}

# Copy Static files, modify existing Puppet module files
Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath 'src/internal/templates/static/*') -Destination $moduleDir -Recurse -Force
$metadatajson = Get-Content -Path (Join-Path $moduleDir "metadata.json") | ConvertFrom-Json
$metadatajson.dependencies = @( @{ "name" = "puppetlabs/pwshlib"; "version_requirement" = ">= 0.4.0 < 2.0.0" } )
[IO.File]::WriteAllLines(
  (Join-Path $moduleDir "metadata.json"),
  (ConvertTo-Json -InputObject $metadatajson)
)
$FixturesYaml = Get-Content -Path (Join-Path $moduleDir ".fixtures.yml") -Raw | ConvertFrom-Yaml
$FixturesYaml.fixtures.forge_modules = @{pwshlib = 'puppetlabs/pwshlib'}
[IO.File]::WriteAllLines(
  (Join-Path $moduleDir ".fixtures.yml"),
  ("---`n" + (ConvertTo-Yaml -Data $FixturesYaml))
)

# build puppet types from dsc resources
[string]$puppetTypeDir              = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'type')
[string]$puppetProviderDir          = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'provider')


$oldPsModulePath  = $env:PSModulePath
$env:PSModulePath = "$($downloadedDscResources);"
$resources = Get-DscResource -Module $PowerShellModuleName | Get-DscResourceTypeInformation

# Files are written using UTF8, but newlines will need to addressed
foreach($Resource in $Resources){

  $dscResourceName = "dsc_$($Resource.Name.ToLowerInvariant())"
  if(-not(Test-Path $puppetTypeDir)){
    mkdir $puppetTypeDir | Out-Null
  }
  [string]$puppetTypeFileName = [IO.Path]::Combine($puppetTypeDir, "$($dscResourceName).rb")
  $puppetTypeText = Get-TypeContent $Resource
  [IO.File]::WriteAllLines($puppetTypeFileName, $puppetTypeText)

  [string]$puppetTypeProviderDir  = Join-Path $puppetProviderDir "$($dscResourceName)"
  [string]$puppetProviderFileName = [IO.Path]::Combine($puppetProviderDir, "$($dscResourceName)", "$($dscResourceName).rb")
  if(-not(Test-Path $puppetTypeProviderDir)){
    mkdir $puppetTypeProviderDir | Out-Null
  }
  $puppetProviderText = Get-ProviderContent $Resource
  [IO.File]::WriteAllLines($puppetProviderFileName, $puppetProviderText)

  $resource = $Null
}
$env:PSModulePath = $oldPsModulePath
