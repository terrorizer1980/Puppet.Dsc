[CmdletBinding()]
param(
  $PuppetModuleName,
  $PowerShellModuleName = 'PowerShellGet',
  $PowerShellModuleVersion
)

If ($null -eq $PuppetModuleName) { $PuppetModuleName = $PowerShellModuleName.tolower() }

$importDir   = Join-Path $PSScriptRoot 'import'
$templateDir = Join-Path $PSScriptRoot 'templates'
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

# create new pdk module
if(-not(Test-Path $importDir)){
  mkdir $importDir
}
if(Test-Path $moduleDir){
  Remove-Item -Path $moduleDir -Force -Recurse
}

## copy pdk specific files
Copy-Item -Path (Join-Path -Path $templateDir 'pdk/*') -Destination $moduleDir -Recurse -Force
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

# copy resource_api base classes
Get-ChildITem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'templates/resource_api/*') | Copy-Item -Destination $moduleDir -Recurse -Force

# build puppet types from dsc resources
[string]$puppetTypeTemplate         = [IO.Path]::Combine($PSScriptRoot, 'templates', 'dsc_type.eps')
[string]$puppetProviderTemplate     = [IO.Path]::Combine($PSScriptRoot, 'templates', 'dsc_provider.eps')
[string]$dscResourcePowerShellTypes = [IO.Path]::Combine($PSScriptRoot, 'templates', 'dsc_resource_types.ps1xml')
[string]$puppetTypeDir              = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'type')
[string]$puppetProviderDir          = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'provider')

Update-TypeData -PrependPath $dscResourcePowerShellTypes

If (!(Get-Module -Name 'EPS' -ListAvailable)) {
  Install-Module -Name 'EPS'
}
Import-Module -Name 'EPS'

$oldPsModulePath  = $env:PSModulePath
$env:PSModulePath = "$($downloadedDscResources);"
$global:resources = Get-DscResource -Module $PowerShellModuleName

# EPS requires global variables to keep them in accessible scope
# Also need to set the variable to null inside the loop
# Files are written using UTF8, but newlines will need to addressed
foreach($resource in $resources){
  $global:resource = $resource

  $dscResourceName = "dsc_$($resource.Name.ToLowerInvariant())"
  if(-not(Test-Path $puppetTypeDir)){
    mkdir $puppetTypeDir | Out-Null
  }
  [string]$puppetTypeFileName = [IO.Path]::Combine($puppetTypeDir, "$($dscResourceName).rb")
  $puppetTypeText = Invoke-EpsTemplate -Path $puppetTypeTemplate
  [IO.File]::WriteAllText($puppetTypeFileName, $puppetTypeText, [Text.Encoding]::UTF8)

  [string]$puppetTypeProviderDir  = Join-Path $puppetProviderDir "$($dscResourceName)"
  [string]$puppetProviderFileName = [IO.Path]::Combine($puppetProviderDir, "$($dscResourceName)", "$($dscResourceName).rb")
  if(-not(Test-Path $puppetTypeProviderDir)){
    mkdir $puppetTypeProviderDir | Out-Null
  }
  $puppetProviderText = Invoke-EpsTemplate -Path $puppetProviderTemplate
  [IO.File]::WriteAllText($puppetProviderFileName, $puppetProviderText, [Text.Encoding]::UTF8)

  $resource = $Null
}
$env:PSModulePath = $oldPsModulePath
