Describe 'Update-PuppetModuleMetadata' {
  InModuleScope puppet.dsc {
    Context 'Basic Verification' {
      # Copy fixtures over
      $MetadataFixtureFile = Resolve-Path -Path "$(Split-Path $PSScriptRoot -Parent)/fixtures/metadata.json"
      $PuppetFolderPath = 'TestDrive:\'
      Copy-Item -Path $MetadataFixtureFile -Destination $PuppetFolderPath
      $ManifestFixtureFile = Resolve-Path -Path "$(Split-Path $PSScriptRoot -Parent)/fixtures/PowerShellGet.psd1"
      $ManifestFilePath = 'TestDrive:\PowerShellGet.psd1'
      Copy-Item -Path $ManifestFixtureFile -Destination $ManifestFilePath
      $ManifestData = Import-PSFPowerShellDataFile -Path $ManifestFixtureFile
      $ManifestDataNoHelpUri = Import-PSFPowerShellDataFile -Path $ManifestFixtureFile
      $ManifestDataNoHelpUri.Remove('HelpInfoURI')
      $ManifestDataValidGithub = Import-PSFPowerShellDataFile -Path $ManifestFixtureFile
      $ManifestDataValidGithub.PrivateData.PSData.ProjectUri = 'https://github.com/foo'
      $ManifestDataInvalidGithub = Import-PSFPowerShellDataFile -Path $ManifestFixtureFile
      $ManifestDataInvalidGithub.PrivateData.PSData.ProjectUri = 'https://github.com/bar'

      Context 'Parameter handling' {
        Mock ConvertTo-UnescapedJson { return $InputObject }
        Mock Out-Utf8File { return $InputObject }
        Mock Import-PSFPowerShellDataFile { $ManifestData }
        Mock Invoke-WebRequest {}

        It 'Errors if the specified Puppet metadata file cannot be found' {
          # NB: This test may only work on English language test nodes?
          { Update-PuppetModuleMetadata -PuppetModuleFolderPath TestDrive:\foo\bar -PowerShellModuleManifestPath $ManifestFilePath } |
            Should -Throw "Cannot find path 'TestDrive:\foo\bar\metadata.json' because it does not exist."
        }
        It 'Errors if the specified PowerShell module manifest cannot be found' {
          { Update-PuppetModuleMetadata -PuppetModuleFolderPath $PuppetFolderPath -PowerShellModuleManifestPath TestDrive:\foo\bar } |
            Should -Throw "Cannot find path 'TestDrive:\foo\bar' because it does not exist."
        }
        It 'Overwrites the module author only if specified' {
          $UnspecifiedResult = Update-PuppetModuleMetadata -PuppetModuleFolderPath $PuppetFolderPath -PowerShellModuleManifestPath $ManifestFilePath
          $SpecifiedResult = Update-PuppetModuleMetadata -PuppetModuleFolderPath $PuppetFolderPath -PowerShellModuleManifestPath $ManifestFilePath -PuppetModuleAuthor override
          $UnspecifiedResult.author | Should -BeExactly 'someone'
          $UnspecifiedResult.name   | Should -MatchExactly '^someone-'
          $SpecifiedResult.author   | Should -BeExactly 'override'
          $SpecifiedResult.name     | Should -MatchExactly '^override-'
        }
      }
      Context 'Updating Metadata' {
        Mock ConvertTo-UnescapedJson { return $InputObject }
        Mock Out-Utf8File { return $InputObject }
        Mock Import-PSFPowerShellDataFile { $ManifestData }
        Mock Invoke-WebRequest {}

        $Result = Update-PuppetModuleMetadata -PuppetModuleFolderPath $PuppetFolderPath -PowerShellModuleManifestPath $ManifestFilePath

        It 'Converts to JSON' {
          Assert-MockCalled ConvertTo-UnescapedJson -Times 1
        }
        It 'Writes the file once' {
          Assert-MockCalled Out-Utf8File -Times 1
        }
        It 'Updates the version' {
          $Result.version | Should -Be '2.2.3'
        }
        It 'Updates the summary' {
          $Result.summary | Should -Be 'PowerShell module with commands for discovering, installing, updating and publishing the PowerShell artifacts like Modules, DSC Resources, Role Capabilities and Scripts.'
        }
        It 'Updates the source' {
          $Result.source | Should -Be 'https://go.microsoft.com/fwlink/?LinkId=828955'
        }
        It 'Updates the issues url' {
          $Result.issues_url | Should -Be 'https://go.microsoft.com/fwlink/?LinkId=828955'
        }
        It 'Updates the project page' {
          $Result.project_page | Should -Be 'http://go.microsoft.com/fwlink/?linkid=2113539'
        }
        It 'Updates the dependencies' {
          $Result.dependencies[0].Name | Should -Be 'puppetlabs/pwshlib'
          $Result.dependencies[0].version_requirement | Should -Be '>= 0.4.0 < 2.0.0'
        }
        It 'Updates the supported operating system list' {
          $Result.operatingsystem_support[0].operatingsystem | Should -Be 'windows'
          $Result.operatingsystem_support[0].operatingsystemrelease | Should -Contain '2012'
          $Result.operatingsystem_support[0].operatingsystemrelease | Should -Contain '2012R2'
          $Result.operatingsystem_support[0].operatingsystemrelease | Should -Contain '2016'
          $Result.operatingsystem_support[0].operatingsystemrelease | Should -Contain '2019'
        }
        It 'Updates the Puppet lower bound' {
          $Result.requirements[0].version_requirement | Should -Be '>= 6.0.0 < 7.0.0'
        }
      }
      Context 'Edge Cases' {
        Context 'Issues Url' {
          Mock ConvertTo-UnescapedJson { return $InputObject }
          Mock Out-Utf8File { return $InputObject }
          Mock Invoke-WebRequest { If ($Uri -match 'bar') {throw 'Site not found'} }
          It 'Sets the issues url to the issues tab of a repo, if it can resolve the Project URI to a valid git repo' {
            # Replace the Project URI with a "valid" GitHub repo URI, should direct to the issues tab:
            Mock Import-PSFPowerShellDataFile { $ManifestDataValidGithub }
            Update-PuppetModuleMetadata -PuppetModuleFolderPath $PuppetFolderPath -PowerShellModuleManifestPath $ManifestFilePath |
              Select-Object -ExpandProperty issues_url | Should -Be 'https://github.com/foo/issues'
          }
          It 'Sets the issues url to the repo if it cannot resolve the issues tab' {
            # Replace the Project URI with an "invalid" GitHub repo URI; should be the URI, not the issues tab:
            Mock Import-PSFPowerShellDataFile { $ManifestDataInvalidGithub }
            Update-PuppetModuleMetadata -PuppetModuleFolderPath $PuppetFolderPath -PowerShellModuleManifestPath $ManifestFilePath |
              Select-Object -ExpandProperty issues_url | Should -Be 'https://github.com/bar'
          }
        }
        Context 'Project Page' {
          Mock ConvertTo-UnescapedJson { return $InputObject }
          Mock Out-Utf8File { return $InputObject }
          Mock Import-PSFPowerShellDataFile { $ManifestDataNoHelpUri }
          Mock Invoke-WebRequest {}
          It 'Defaults to the project uri if no Help URI is specified' {
            # Remove the HelpUri from the manifest
            Get-Content -Path $ManifestFilePath | Where-Object -FilterScript {$_ -notmatch 'HelpUri' } | Out-File $ManifestFilePath
            Update-PuppetModuleMetadata -PuppetModuleFolderPath $PuppetFolderPath -PowerShellModuleManifestPath $ManifestFilePath |
              Select-Object -ExpandProperty project_page | Should -Be 'https://go.microsoft.com/fwlink/?LinkId=828955'
          }
        }
      }
    }
  }
}