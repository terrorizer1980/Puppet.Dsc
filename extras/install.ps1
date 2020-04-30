$ChocolateyPackages = @(
  'pester'
  'pdk'
)

if ($ENV:CI -ne 'True') {
  $ChocolateyPackages += @(
    'vscode'
    'vscode-powershell'
    'googlechrome'
    'git'
  )
}

choco install $ChocolateyPackages -y --no-progress
$PowerShellModules = @(
  @{ Name = 'PSFramework' }
  @{ Name = 'PSModuleDevelopment' }
  @{ Name = 'PowerShellGet' ; RequiredVersion = '2.2.3' }
  @{ Name = 'powershell-yaml' }
  @{ Name = 'PSScriptAnalyzer' }
  @{ Name = 'PSDepend' }
  @{ Name = 'xPSDesiredStateConfiguration' }
  @{ Name = 'PSDscResources' ; RequiredVersion = '2.12.0.0' }
  @{ Name = 'AccessControlDsc' ; RequiredVersion = '1.4.0.0' }
)
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
ForEach ($Module in $PowerShellModules) {
  Install-Module @Module -Force
}
