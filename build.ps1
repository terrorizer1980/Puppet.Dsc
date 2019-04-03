[CmdletBinding()]
param(
  $ModuleName = 'dsc_api'
)

$importDir   = Join-Path $PSScriptRoot 'import'
$templateDir = Join-Path $PSScriptRoot 'templates'
$moduleDir   = Join-Path $importDir $ModuleName

# import dsc resources from psgallery
$dscResourceSheet          = Join-Path $PSScriptRoot 'import.csv'
$downloadedDscResources    = Join-Path $importDir 'dsc_resources'
$downloadedDscResourcesTmp = "$($downloadedDscResources)_tmp"

if(-not(Test-Path $downloadedDscResources)){
  if(-not(Test-Path $downloadedDscResources)){
    mkdir $downloadedDscResources
  }
  if(-not(Test-Path $downloadedDscResourcesTmp)){
    mkdir $downloadedDscResourcesTmp
  }
  $items = Import-Csv -Path $dscResourceSheet
  $items | ForEach-Object {
    Save-Module -Name $_.Name -Path $downloadedDscResourcesTmp -RequiredVersion $_.Version
    Move-Item -Path "$($downloadedDscResourcesTmp)/$($_.Name)/$($_.Version)" -Destination "$($downloadedDscResources)/$($_.Name)"
  }
}

# create new pdk module
if(-not(Test-Path $importDir)){
  mkdir $importDir
}
if(Test-Path $moduleDir){
  Remove-Item -Path $moduleDir -Force -Recurse
}
Push-Location  $importDir
pdk new module --skip-interview --template-url "https://github.com/puppetlabs/pdk-templates" $ModuleName
Pop-Location

## copy pdk specific files
Copy-Item -Path (Join-Path -Path $templateDir 'pdk/*') -Destination $moduleDir -Recurse -Force

# copy power_manager code
Get-ChildITem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'templates/powershell_manager/*') | Copy-Item -Destination $moduleDir -Recurse -Force

# copy resource_api base classes
Get-ChildITem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'templates/resource_api/*') | Copy-Item -Destination $moduleDir -Recurse -Force

# build puppet types from dsc resources
[string]$puppetTypeTemplate         = [IO.Path]::Combine($PSScriptRoot, 'templates', 'dsc_type.eps')
[string]$puppetProviderTemplate     = [IO.Path]::Combine($PSScriptRoot, 'templates', 'dsc_provider.eps')
[string]$dscResourcePowerShellTypes = [IO.Path]::Combine($PSScriptRoot, 'templates', 'dsc_resource_types.ps1xml')
[string]$puppetTypeDir              = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'type')
[string]$puppetProviderDir          = [IO.Path]::Combine($moduleDir, 'lib', 'puppet', 'provider')

Update-TypeData -PrependPath $dscResourcePowerShellTypes

$oldPsModulePath = $env:PSModulePath
$env:PSModulePath = "$($downloadedDscResources);" + $env:PSModulePath
$global:resources = Get-DscResource

ipmo C:\Users\james\src\puppetlabs\eps\EPS\EPS.psd1
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
