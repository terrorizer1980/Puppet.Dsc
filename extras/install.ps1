[cmdletbinding()]
Param(
  [switch]$Full
)

$ErrorActionPreference = 'Stop'

$ChocolateyPackages = @(
  'Pester'
)

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
    'conemu'
  )
  $PowerShellModules += @(
    @{ Name = 'RubyInstaller' }
  )
}

If ($Full -or $ENV:CI -eq 'True') {
  Write-Host 'Ensuring WinRM is configured for DSC'
  Get-ChildItem WSMan:\localhost\Listener\ -OutVariable Listeners | Format-List * -Force
  $HTTPListener = $Listeners | Where-Object -FilterScript { $_.Keys.Contains('Transport=HTTP') }
  If ($HTTPListener.Count -eq 0) {
    winrm create winrm/config/Listener?Address=*+Transport=HTTP
    winrm e winrm/config/listener
  }
}

$Choco = Get-Command choco -ErrorAction SilentlyContinue
If ($null -eq $Choco) {
  Write-Host 'Installing Chocolatey'
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host "Installing with choco: $ChocolateyPackages"

choco install $ChocolateyPackages --yes --no-progress --stop-on-first-failure --ignore-checksums
if ($LastExitCode -ne 0) {
  throw 'Installation with choco failed.'
}

Write-Host 'Reloading Path to pick up installed software'
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyProfile.psm1
Update-SessionEnvironment

Get-Module -ListAvailable -Name $PowerShellModules.Name -ErrorAction SilentlyContinue

Write-Host "Installing $($PowerShellModules.Count) modules with Install-Module"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -Verbose:$false
ForEach ($Module in $PowerShellModules) {
  $InstalledModuleVersions = Get-Module -ListAvailable $Module.Name -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Version
  If ($Module.ContainsKey('RequiredVersion')) {
    $AlreadyInstalled = $null -ne ($InstalledModuleVersions | Where-Object -FilterScript { $_ -eq $Module.RequiredVersion })
  } Else {
    $AlreadyInstalled = $null -ne $InstalledModuleVersions
  }
  If ($AlreadyInstalled) {
    Write-Verbose "Skipping $($Module.Name) as it is already installed at $($InstalledModuleVersions)"
  } Else {
    Write-Verbose "Installing $($Module.Name)"
    Install-Module @Module -Force -SkipPublisherCheck -AllowClobber
  }
}

Get-Module -ListAvailable -Name $PowerShellModules.Name

if ($ENV:CI -ne 'True' -and $Full) {
  Import-Module 'RubyInstaller'
  Install-Ruby -RubyVersions @('2.5.1-2 (x64)', '2.7.2-1 (x64)') -Verbose
}
