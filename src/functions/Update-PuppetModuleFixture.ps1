function Update-PuppetModuleFixture {
  <#
    .SYNOPSIS
      Update the Puppet module's .fixtures.yml
    .DESCRIPTION
      Update the Puppet module's .fixtures.yml with dependencies.
    .PARAMETER PuppetModuleFolderPath
      The Path, relative or literal, to the Puppet module's root folder.
    .PARAMETER Confirm
      Prompts for confirmation before overwriting the file
    .PARAMETER WhatIf
      Shows what would happen if the function runs.
    .EXAMPLE
      Update-PuppetModuleFixture -PuppetModuleFolderPath ./import/powershellget
      This command will update `./import/powershellget/.fixtures.yml`, adding a
      key to the Forge Modules fixture for puppetlabs/pwshlib.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param (
    [string]$PuppetModuleFolderPath
  )

  begin {}

  process {
    Try {
      $ErrorActionPreference = 'Stop'
      $FixturesFilePath = Resolve-Path -Path (Join-Path $PuppetModuleFolderPath ".fixtures.yml")
      $FixturesYaml = Get-Content -Path $FixturesFilePath -Raw | ConvertFrom-Yaml
      $FixturesYaml.fixtures.forge_modules = @{
        pwshlib = 'puppetlabs/pwshlib'
      }
    } Catch {
      # Rethrow any exceptions from the above commands
      $PSCmdlet.ThrowTerminatingError($PSItem)
    }
    $YamlOutput = "---`n" + (ConvertTo-Yaml -Data $FixturesYaml)
    If ($PSCmdlet.ShouldProcess($FixturesFilePath, "Overwrite YAML with:`n`n$YamlOutput")) {
      Out-Utf8File -Path $FixturesFilePath -InputObject $YamlOutput
    }
  }

  end {}
}