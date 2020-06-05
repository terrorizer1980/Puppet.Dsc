function Publish-PuppetModule {
    <#
      .SYNOPSIS
        Build and Publish Module
      .DESCRIPTION
        Generate package for the Puppet module and publish to the forge.
      .PARAMETER PuppetModuleFolderPath
        The path, relative or literal, to the Puppet module's root folder.
      .PARAMETER ForgeUploadUrl
        The Forge Upload Url Path and default is https://forgeapi.puppetlabs.com/v3/releases.
      .PARAMETER ForgeToken
        The Forge Token.
      .PARAMETER Build
        Flag to build the package.
      .PARAMETER Publish
        Flag to publish the package.
      .EXAMPLE
        Publish-PuppetModule -PuppetModuleFolderPath C:\output\testmodule -ForgeUploadUrl https://forgeapi.puppetlabs.com/v3/releases -ForgeToken testmoduletoken -Build true -Publish true
        This command will createo or use existing pkg and Publishes the <tarball> to the Forge , for the `testmodule` depends on the options passed for pdk release command.
    #>
    #>
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$True)]
      $PuppetModuleFolderPath,
      [string]$ForgeToken,
      [string]$ForgeUploadUrl,
      [string]$Build,
      [string]$Publish
    )

    begin {
      $PuppetModuleFolderPath = Resolve-Path -Path $PuppetModuleFolderPath -ErrorAction Stop
      If ($Publish -eq 'true') {
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
        If ($Build -eq 'true')  {
          Invoke-PdkCommand -Path $PuppetModuleFolderPath -Command $CommandBuild -SuccessFilterScript {
            $_ -match "completed successfully"
          }
        }
        If ($Publish -eq 'true') {
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
