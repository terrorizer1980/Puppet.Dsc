<#
    .SYNOPSIS
      Puppetize a PowerShell module with DSC resources
    .DESCRIPTION
      This function builds a Puppet Module which wraps and calls PowerShell DSC resources
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
    .PARAMETER PuppetModuleAuthor
      The name of the Puppet module author; if not specified, will default to your PDK configuration's author.
    .PARAMETER OutputDirectory
      The folder in which to build the Puppet module. Defaults to a folder called import in the current location.
    .PARAMETER PassThru
      If specified, the function returns the path to the root folder of the Puppetized module on the filesystem.
    .PARAMETER Confirm
      Prompts for confirmation before creating the Puppet module
    .PARAMETER WhatIf
      Shows what would happen if the function runs.
    .EXAMPLE
      Build.ps1 -PowerShellModuleName PowerShellGet -PowerShellModuleVersion 2.2.3

      This function will create a new Puppet module, powershellget, which vendors and puppetizes the PowerShellGet
      PowerShell module at version 2.2.3 and its dependencies, exposing the DSC resources as Puppet resources.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory=$True)]
    [string]$PowerShellModuleName,
    [string]$PowerShellModuleVersion,
    [string]$PuppetModuleName,
    [string]$PuppetModuleAuthor,
    [string]$OutputDirectory,
    [switch]$PassThru
  )

Import-Module PuppetDevelopmentKit
Import-Module "$PSScriptRoot/src/puppet.dsc.psd1" -Force

New-PuppetDscModule @PSBoundParameters
