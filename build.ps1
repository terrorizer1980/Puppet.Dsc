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
  [string]$PuppetModuleName,
  [string]$PuppetModuleAuthor,
  [string]$PowerShellModuleName,
  [string]$PowerShellModuleVersion
)

Import-Module PuppetDevelopmentKit
Import-Module "$PSScriptRoot/src/puppet.dsc.psd1" -Force

New-PuppetDscModule @PSBoundParameters
