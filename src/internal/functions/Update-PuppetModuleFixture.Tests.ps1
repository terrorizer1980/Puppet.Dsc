BeforeAll {
  $ModuleRootPath = Split-Path -Parent $PSCommandPath |
    Split-Path -Parent |
    Split-Path -Parent
  Import-Module "$ModuleRootPath/Puppet.Dsc.psd1"
  . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe 'Update-PuppetModuleFixture' {
  InModuleScope puppet.dsc {
    Context 'Basic Verification' {
      BeforeAll {
        Mock Out-Utf8File { return $InputObject }
        # Create a Mock fixtures File
        New-Item -Path TestDrive:\.fixtures.yml -Value @'
---
fixtures:
  forge_modules:
'@
      }

      It 'Errors if the file cannot be found' {
        # NB: This test may only work on English language test nodes?
        { Update-PuppetModuleFixture -PuppetModuleFolderPath TestDrive:\foo\bar } | Should -Throw "Cannot find path 'TestDrive:\foo\bar\.fixtures.yml' because it does not exist."
      }
      It 'Writes a Yaml File' {
        $Result = Update-PuppetModuleFixture -PuppetModuleFolderPath TestDrive:\
        # Must start with yaml indicator for Puppet to be happy
        $Result | Should -Match '^---'
        # Must include all needed dependencies
        $Result | Should -Match 'pwshlib: puppetlabs/pwshlib'
      }
    }
  }
}
