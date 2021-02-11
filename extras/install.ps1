[cmdletbinding()]
Param(
  [switch]$Full
)

$ErrorActionPreference = "Stop"

$ChocolateyPackages = @('Pester')

$PowerShellModules = @(
  @{ Name = 'PSFramework' }
  @{ Name = 'PSModuleDevelopment' ; RequiredVersion = '2.2.7.90' }
  @{ Name = 'PowerShellGet' ; RequiredVersion = '2.2.3' }
  @{ Name = 'powershell-yaml' }
  @{ Name = 'PSScriptAnalyzer' }
  @{ Name = 'PSDepend' }
  @{ Name = 'xPSDesiredStateConfiguration' }
  @{ Name = 'PSDscResources' ; RequiredVersion = '2.12.0.0' }
  @{ Name = 'AccessControlDsc' ; RequiredVersion = '1.4.0.0' }
)

If ($Full) {
  $ChocolateyPackages += 'pdk'
}

if ($ENV:CI -ne 'True' -and $Full) {
  $ChocolateyPackages += @(
    'vscode'
    'vscode-powershell'
    'googlechrome'
    'git'
    'poshgit'
    'curl'
  )
  $PowerShellModules += @(
    @{ Name = 'RubyInstaller' }
  )
}

Write-Host "Installing with choco: $ChocolateyPackages"

choco install $ChocolateyPackages --yes --no-progress --stop-on-first-failure
if ($LastExitCode -ne 0) {
  throw "Installation with choco failed."
}

Write-Host "Installing $($PowerShellModules.Count) modules with Install-Module"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
ForEach ($Module in $PowerShellModules) {
  Install-Module @Module -Force
}

if ($ENV:CI -ne 'True') {
  Import-Module 'RubyInstaller'
  # Non-functional, pending an investigation and PR to RubyInstaller?
  # For now you need to run it interactively
  # Install-Ruby -RubyVersions '2.5.1' -Verbose
}
