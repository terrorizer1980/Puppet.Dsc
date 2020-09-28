Describe 'Update-PuppetModuleChangelog' {
  InModuleScope puppet.dsc {
    Context 'Basic Verification' {
      # Setup fixtures
      $PuppetFolderPath = 'TestDrive:\puppet_module'
      New-Item -Path "$PuppetFolderPath/Changelog.md" -Force
      $ManifestFixtureFile = Resolve-Path -Path "$(Split-Path $PSScriptRoot -Parent)/fixtures/PowerShellGet.psd1"
      $ManifestFilePath = 'TestDrive:\PowerShellGet.psd1'
      Copy-Item -Path $ManifestFixtureFile -Destination $ManifestFilePath
      # Import from the Manifest Fixture
      $ManifestData = Import-PSFPowerShellDataFile -Path $ManifestFixtureFile
      $ManifestDataNoReleaseNotes = Import-PSFPowerShellDataFile -Path $ManifestFixtureFile
      $ManifestDataNoReleaseNotes.PrivateData.PSData.Remove('ReleaseNotes')

      Context 'Parameter handling' {
        Mock Import-PSFPowerShellDataFile { return $ManifestData }
        Mock Out-Utf8File                 { }

        It 'Errors if the specified Puppet changelog file cannot be found' {
          $Parameters = @{
            PowerShellModuleManifestPath = $ManifestFilePath
            PuppetModuleFolderPath = 'TestDrive:\foo\bar'
          }
          # NB: This test may only work on English language test nodes?
          { Update-PuppetModuleChangelog @Parameters } | Should -Throw "Cannot find path 'TestDrive:\foo\bar\CHANGELOG.md' because it does not exist."
        }
        It 'Errors if the specified PowerShell module manifest cannot be found' {
          $Parameters = @{
            PowerShellModuleManifestPath = 'TestDrive:\foo\bar'
            PuppetModuleFolderPath = $PuppetFolderPath
          }
          { Update-PuppetModuleChangelog @Parameters  } | Should -Throw "Cannot find path 'TestDrive:\foo\bar' because it does not exist."
        }
      }
      Context 'When Release Notes exist' {
        Mock Import-PSFPowerShellDataFile { return $ManifestData }
        Mock Out-Utf8File                 { return $InputObject }

        $Parameters = @{
          PowerShellModuleManifestPath = $ManifestFilePath
          PuppetModuleFolderPath = $PuppetFolderPath
        }
        $Result = Update-PuppetModuleChangelog @Parameters

        It 'Writes the file once with the ReleaseNotes as the content' {
          Assert-MockCalled Out-Utf8File -Times 1
          $Result | Should -Be $ManifestData.PrivateData.PSData.ReleaseNotes
        }
      }
      Context 'When neither Release Notes nor a changelog exist' {
        Mock Import-PSFPowerShellDataFile { return $ManifestDataNoReleaseNotes }
        Mock Out-Utf8File                 { return $InputObject }

        $Parameters = @{
          PowerShellModuleManifestPath = $ManifestFilePath
          PuppetModuleFolderPath = $PuppetFolderPath
        }
        Update-PuppetModuleChangelog @Parameters

        It 'Does not write to the file' {
          Assert-MockCalled Out-Utf8File -Times 0
        }
      }
      Context 'When Release Notes do not exist but a changelog does' {
        New-Item -path 'TestDrive:\CHANGELOG.md' -Value 'foo'
        Mock Import-PSFPowerShellDataFile { return $ManifestDataNoReleaseNotes }
        Mock Out-Utf8File                 { return $InputObject }

        $Parameters = @{
          PowerShellModuleManifestPath = $ManifestFilePath
          PuppetModuleFolderPath = $PuppetFolderPath
        }
        $Result = Update-PuppetModuleChangelog @Parameters

        It 'Writes the file once with the CHANGELOG as the content' {
          Assert-MockCalled Out-Utf8File -Times 1
          $Result | Should -Be 'foo'
        }
      }
    }
  }
}
