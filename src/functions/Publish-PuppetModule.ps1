function Publish-PuppetModule {
    <#
      .SYNOPSIS
        Build and Publish Puppet Module
      .DESCRIPTION
        Generate package for the module and publish to the forge.
      .PARAMETER PuppetModuleFolderPath
        The path, relative or absolute, to the Puppet module's root folder.
      .PARAMETER ForgeUploadUrl
        The URL for the Forge Upload API. Defaults to the public forge.
      .PARAMETER ForgeToken
        The Forge API Token for the target account.
      .PARAMETER Build
        Flag whether to build the package.
      .PARAMETER Publish
        Flag whether to publish the package.
      .EXAMPLE
        Publish-PuppetModule -PuppetModuleFolderPath C:\output\testmodule -ForgeUploadUrl https://forgeapi.puppetlabs.com/v3/releases -ForgeToken testmoduletoken -Build true -Publish true
        This command will create or use existing pkg and Publishes the <tarball> to the Forge , for the `testmodule` depends on the options passed for pdk release command.
    #>
    #>
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$True)]
      $PuppetModuleFolderPath,
      [string]$ForgeToken,
      [string]$ForgeUploadUrl,
      [bool]$Build,
      [bool]$Publish
    )

    begin {
      $PuppetModuleFolderPath = Resolve-Path -Path $PuppetModuleFolderPath -ErrorAction Stop
      If ($Publish) {
        If ([string]::IsNullOrEmpty($ForgeUploadUrl)) {
          $CommandPublish = "pdk release publish --forge-token $ForgeToken"
        } Else {
          $CommandPublish = "pdk release publish --forge-token $ForgeToken --forge-upload-url $ForgeUploadUrl"
        }
      }
      If ((![string]::IsNullOrEmpty($Build)) -AND ($Build -eq 'true')) {
        $CommandBuild = 'pdk build'
      }
    }
    process {
      Try {
        $ErrorActionPreference = 'Stop'
        If ($Build)  {
          Invoke-PdkCommand -Path $PuppetModuleFolderPath -Command $CommandBuild -SuccessFilterScript {
            $_ -match "completed successfully"
          }
        }
        If ($Publish) {
          Invoke-PdkCommand -Path $PuppetModuleFolderPath -Command $CommandPublish -SuccessFilterScript {
            $_ -match "Publish to Forge was successful"
          }
        }
      } Catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
      }
    }
    end {}
  }
