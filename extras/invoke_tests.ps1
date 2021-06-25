[cmdletbinding()]
Param(
  [Parameter(Mandatory = $true)]
  [string[]]$TestPath,
  [Parameter(Mandatory = $true)]
  [string]$ResultsPath,
  [string]$Tag
)

$ErrorActionPreference = 'Stop'

Get-Module -Name Pester | Remove-Module
Import-Module -Name Pester -MinimumVersion 5.0.0

$ProjectRoot = Split-Path -Parent $PSCommandPath |
  Split-Path -Parent |
  Resolve-Path
Import-Module -Name (Join-Path -Path $ProjectRoot -ChildPath 'src/puppet.dsc.psd1')

$PesterConfiguration = New-PesterConfiguration
$PesterConfiguration.Output.Verbosity = 'Detailed'
$PesterConfiguration.Run.Path = $TestPath
$PesterConfiguration.Run.PassThru = $true

If ($ResultsPath) {
  $PesterConfiguration.TestResult.Enabled = $true
  $PesterConfiguration.TestResult.OutputPath = $ResultsPath
}

If ($null -ne $Tag) {
  $PesterConfiguration.Filter.Tag = $Tag
}

Invoke-Pester -Configuration $PesterConfiguration
