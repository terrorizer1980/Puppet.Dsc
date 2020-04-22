Describe 'Update-PuppetModuleReadme' {
  InModuleScope puppet.dsc {
    Context 'Basic Verification' {
      # Setup fixtures
      $PuppetFolderPath = 'TestDrive:\'
      New-Item -Path "$PuppetFolderPath/README.md"
      $ManifestFixtureFile = Resolve-Path -Path "$(Split-Path $PSScriptRoot -Parent)/fixtures/PowerShellGet.psd1"
      $ManifestFilePath = 'TestDrive:\PowerShellGet.psd1'
      Copy-Item -Path $ManifestFixtureFile -Destination $ManifestFilePath
      # Import from the Manifest Fixture
      $ManifestData = Import-PSFPowerShellDataFile -Path $ManifestFixtureFile

      Context 'Parameter handling' {
        Mock Import-PSFPowerShellDataFile { return $ManifestData }
        Mock Get-ReadmeContent            { return 'Content' }
        Mock Get-PuppetizedModuleName     { return 'foo' }
        Mock Out-Utf8File                 { }

        It 'Errors if the specified Puppet readme file cannot be found' {
          $Parameters = @{
            PowerShellModuleManifestPath = $ManifestFilePath
            PowerShellModuleName = 'PowerShellGet'
            PuppetModuleFolderPath = 'TestDrive:\foo\bar'
            PuppetModuleName = 'powershellget'
          }
          # NB: This test may only work on English language test nodes?
          { Update-PuppetModuleReadme @Parameters } | Should -Throw "Cannot find path 'TestDrive:\foo\bar\README.md' because it does not exist."
        }
        It 'Errors if the specified PowerShell module manifest cannot be found' {
          $Parameters = @{
            PowerShellModuleManifestPath = 'TestDrive:\foo\bar'
            PowerShellModuleName = 'PowerShellGet'
            PuppetModuleFolderPath = $PuppetFolderPath
            PuppetModuleName = 'powershellget'
          }
          { Update-PuppetModuleReadme @Parameters  } | Should -Throw "Cannot find path 'TestDrive:\foo\bar' because it does not exist."
        }
        It 'Sets the Puppet module name if not specified' {
          $Parameters = @{
            PowerShellModuleManifestPath = $ManifestFilePath
            PowerShellModuleName = 'PowerShellGet'
            PuppetModuleFolderPath = $PuppetFolderPath
          }
          # Specified
          { Update-PuppetModuleReadme @Parameters -PuppetModuleName override } | Should -Not -Throw
          Assert-MockCalled Get-PuppetizedModuleName -Times 0
          Assert-MockCalled Get-ReadmeContent -Times 1 -ParameterFilter {
            $PuppetModuleName -ceq 'override'
          }
          # Unspecified
          { Update-PuppetModuleReadme @Parameters } | Should -Not -Throw
          Assert-MockCalled Get-PuppetizedModuleName -Times 1
          Assert-MockCalled Get-ReadmeContent -Times 1 -ParameterFilter {
            $PuppetModuleName -ceq 'foo'
          }
        }
      }
      Context 'Updating Readme' {
        Mock Import-PSFPowerShellDataFile { return $ManifestData }
        Mock Get-ReadmeContent            { return 'Content' }
        Mock Out-Utf8File                 { }
        Mock Get-PuppetizedModuleName     { }

        $Parameters = @{
          PowerShellModuleManifestPath = $ManifestFilePath
          PowerShellModuleName = 'PowerShellGet'
          PuppetModuleFolderPath = $PuppetFolderPath
          PuppetModuleName = 'powershellget'
        }
        Update-PuppetModuleReadme @Parameters

        It 'Retrieves the README text' {
          Assert-MockCalled Get-ReadmeContent -Times 1
        }
        It 'Writes the file once' {
          Assert-MockCalled Out-Utf8File -Times 1
        }
        It 'Passes the PowerShell module name' {
          Assert-MockCalled Get-ReadmeContent -Times 1 -ParameterFilter {
            $PowerShellModuleName -eq $Parameters.PowerShellModuleName
          }
        }
        It 'Constructs the PowerShell gallery link' {
          Assert-MockCalled Get-ReadmeContent -Times 1 -ParameterFilter {
            $PowerShellModuleGalleryUri -eq "https://www.powershellgallery.com/packages/$($Parameters.PowerShellModuleName)/$($ManifestData.ModuleVersion)"
          }
        }
        It 'Passes the PowerShell module description, project uri, and version' {
          $Description
          Assert-MockCalled Get-ReadmeContent -Times 1 -ParameterFilter {
            $PowerShellModuleDescription -eq $ManifestData.Description -and
            $PowerShellModuleProjectUri  -eq $ManifestData.PrivateData.PSData.ProjectUri -and
            $PowerShellModuleVersion     -eq $ManifestData.ModuleVersion
          }
        }
      }
    }
  }
}