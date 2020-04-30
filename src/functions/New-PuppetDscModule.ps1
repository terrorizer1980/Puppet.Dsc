Function New-PuppetDscModule {
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
      New-PuppetDscModule -PowerShellModuleName PowerShellGet -PowerShellModuleVersion 2.2.3

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

  Begin {
    # Unless specified, use a valid Puppet module name
    If ([string]::IsNullOrEmpty($PuppetModuleName)) { $PuppetModuleName = Get-PuppetizedModuleName -Name $PowerShellModuleName }
    # Default to the `import` folder in the current path
    If ([string]::IsNullOrEmpty($OutputDirectory))  {
      $OutputDirectory  = Join-Path -Path (Get-Location) -ChildPath 'import'
    } Else {}

    $PuppetModuleRootFolderDirectory = Join-Path -Path $OutputDirectory                 -ChildPath $PuppetModuleName
    $VendoredDscResourcesDirectory   = Join-Path -Path $OutputDirectory                 -ChildPath "$PuppetModuleName/lib/puppet_x/dsc_resources"
    $PuppetModuleTypeDirectory       = Join-Path -Path $PuppetModuleRootFolderDirectory -ChildPath 'lib/puppet/type'
    $PuppetModuleProviderDirectory   = Join-Path -Path $PuppetModuleRootFolderDirectory -ChildPath 'lib/puppet/provider'
    $InitialPSModulePath          = $Env:PSModulePath
    $InitialErrorActionPreference = $ErrorActionPreference
  }

  Process {
    $ShouldProcessMessage = "Puppetize the '$PowerShellModuleName' module"
    If (![string]::IsNullOrEmpty($PowerShellModuleVersion)) { $ShouldProcessMessage += " at version '$PowerShellModule'"}
    If ($PSCmdlet.ShouldProcess($OutputDirectory, $ShouldProcessMessage)) {
      Try {
        $ErrorActionPreference = 'Stop'
        # Scaffold the module via the PDK
        Initialize-PuppetModule -OutputFolderPath $OutputDirectory -PuppetModuleName $PuppetModuleName -verbose

        # Vendor the PowerShell module and all of its dependencies
        Add-DscResourceModule -Name $PowerShellModuleName -Path $VendoredDscResourcesDirectory -RequiredVersion $PowerShellModuleVersion

        # Update the Puppet module metadata
        $PowerShellModuleManifestPath = (Resolve-Path "$VendoredDscResourcesDirectory/$PowerShellModuleName/$PowerShellModuleName.psd1")
        $MetadataParameters = @{
          PuppetModuleFolderPath       = $PuppetModuleRootFolderDirectory
          PowerShellModuleManifestPath = $PowerShellModuleManifestPath
          PuppetModuleAuthor           = $PuppetModuleAuthor
        }
        Update-PuppetModuleMetadata @MetadataParameters

        # Update the Puppet module test fixtures
        Update-PuppetModuleFixture -PuppetModuleFolderPath $PuppetModuleRootFolderDirectory

        # Write the Puppet module README
        Update-PuppetModuleReadme -PuppetModuleFolderPath $PuppetModuleRootFolderDirectory -PowerShellModuleManifestPath $PowerShellModuleManifestPath

        # The PowerShell Module path needs to be munged because the Get-DscResource function always and only
        # checks the PSModulePath for DSC modules; you CANNOT point to a module by path.
        Set-PSModulePath -Path $VendoredDscResourcesDirectory
        $Resources = Get-DscResource -Module $PowerShellModuleName | ConvertTo-PuppetResourceApi

        # Write the type and provider files for each DSC Resource
        foreach($Resource in $Resources){
          $PuppetTypeFilePath          = Join-Path -Path $PuppetModuleTypeDirectory     -ChildPath $Resource.RubyFileName
          $PuppetProviderDirectoryPath = Join-Path -Path $PuppetModuleProviderDirectory -ChildPath $Resource.Name
          $PuppetProviderFilePath      = Join-Path -Path $PuppetProviderDirectoryPath   -ChildPath $Resource.RubyFileName
          if(-not(Test-Path $PuppetModuleTypeDirectory)){
            New-Item -Path $PuppetModuleTypeDirectory -ItemType Directory -Force | Out-Null
          }
          Out-Utf8File -Path $PuppetTypeFilePath -InputObject $Resource.Type
          if(-not(Test-Path $PuppetProviderDirectoryPath)){
            New-Item -Path $PuppetProviderDirectoryPath -ItemType Directory -Force | Out-Null
          }
          Out-Utf8File -Path $PuppetProviderFilePath -InputObject $Resource.Provider
        }
        
        # Generate REFERENCE.md file for the Puppet module from the auto-generated types for each DSC resource
        Set-PSModulePath -Path $InitialPsModulePath
        Add-PuppetReferenceDocumentation -PuppetModuleFolderPath $PuppetModuleRootFolderDirectory -verbose

        If ($PassThru) {
          # Return the folder containing the puppetized module
          Get-Item $PuppetModuleRootFolderDirectory
        }
      } Catch {
        $PSCmdlet.ThrowTerminatingError($PSitem)
      } Finally {
        # Reset the working envrionment
        Set-PSModulePath -Path $InitialPsModulePath
        $ErrorActionPreference = $InitialErrorActionPreference
      }
    }
  }

  End {}
}
