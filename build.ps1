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
# Update the Puppet module metadata
$metadatajson         = Get-Content -Path (Join-Path $moduleDir "metadata.json") | ConvertFrom-Json
$PowerShellMetadata   = Import-PSFPowerShellDataFile -Path (Resolve-Path "$downloadedDscResources/$PowerShellModuleName/$PowerShellModuleName.psd1")
If ($null -ne $PuppetModuleAuthor) {
  $metadatajson.name   = $metadatajson.name -replace '(^\S+)-(\S+)', "$PuppetModuleAuthor-`$2"
  $metadatajson.author = $PuppetModuleAuthor
}
$metadatajson.version = $PowerShellMetadata.ModuleVersion
$metadatajson.summary = $PowerShellMetadata.Description -Replace "(`r`n|`n)", '`n'
$metadatajson.source  = $PowerShellMetadata.PrivateData.PSData.ProjectUri
# If we can find the issues page, link to it, otherwise default to project page.
Switch -Regex ($PowerShellMetadata.PrivateData.PSData.ProjectUri) {
  '(github\.com|gitlab\.com|bitbucket\.com)' {
    $IssueUri = $PowerShellMetadata.PrivateData.PSData.ProjectUri + '/issues'
    Try {
      Invoke-WebRequest -Uri $IssueUri -UseBasicParsing -ErrorAction Stop
      $metadatajson | Add-Member -MemberType NoteProperty -Name issues_url -Value $IssueUri
    } Catch {
      $metadatajson | Add-Member -MemberType NoteProperty -Name issues_url -Value  $PowerShellMetadata.PrivateData.PSData.ProjectUri
    }
  }
  Default { $metadatajson | Add-Member -MemberType NoteProperty -Name issues_url -Value  $PowerShellMetadata.PrivateData.PSData.ProjectUri }
}
# If the HelpInfoURI is specified, use it, otherwise default to project page
If ($null -ne $PowerShellMetadata.PrivateData.PSData.HelpInfoURI) {
  $metadatajson | Add-Member -MemberType NoteProperty -Name project_page -Value $PowerShellMetadata.PrivateData.PSData.HelpUnfoURI
} Else {
  $metadatajson | Add-Member -MemberType NoteProperty -Name project_page -Value $PowerShellMetadata.PrivateData.PSData.ProjectUri
}
# Update the dependencies to include the base DSC provider and PowerShell code manager
$metadatajson.dependencies = @(
  @{
    name = 'puppetlabs/pwshlib'
    version_requirement = '>= 0.4.0 < 2.0.0'
  }
)
# Update the operating sytem to only support windows *for now*.
$metadatajson.operatingsystem_support = @(
  @{
    operatingsystem = 'windows'
    operatingsystemrelease = @(
      '2012',
      '2012R2',
      '2016',
      '2019'
    )
  }
)
# Clarify Puppet lower bound
$metadatajson.requirements[0].version_requirement = '>= 6.0.0 < 7.0.0'

Function ConvertTo-UnescapedJson {
  <#
    .SYNOPSIS
      Convert a  PowerShell object to JSON *without* Unicode escapes
    .DESCRIPTION
      Convert a  PowerShell object to JSON *without* Unicode escapes
    .EXAMPLE
      ConvertTo-UnescapedJson -InputObject @{a = '>=1'}

      Using `ConvertTo-Json` here would output `"a": "\u003e=1"` instead of the
      correct output, `"a": ">=1"`, so running `ConvertTo-UnescapedJson` instead
      ensures the correct string to be passed along.
  #>
  [cmdletbinding()]
  Param($InputObject)

  ConvertTo-Json -InputObject $InputObject -Depth 10 |
    ForEach-Object -Process {
      [System.Text.RegularExpressions.Regex]::Unescape($_)
    }
}

[IO.File]::WriteAllLines(
  (Join-Path $moduleDir "metadata.json"),
  (ConvertTo-UnescapedJson -InputObject $metadatajson)
)

# Update the Puppet module test fixtures
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
