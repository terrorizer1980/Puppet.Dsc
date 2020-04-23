Describe 'Get-ReadmeContent' {
  InModuleScope puppet.dsc {
    Context 'Basic verification' {
      # Copy fixtures over
      # $ManifestFixtureFile = Resolve-Path -Path "$(Split-Path $PSScriptRoot -Parent)/fixtures/PowerShellGet.psd1"
      # $ManifestFilePath = 'TestDrive:\PowerShellGet.psd1'
      # Copy-Item -Path $ManifestFixtureFile -Destination $ManifestFilePath
      $Parameters = @{
        PowerShellModuleName        = 'Foo.Bar'
        PowerShellModuleDescription = 'Foo and bar and baz!'
        PowerShellModuleGalleryUri  = 'https://powershellgallery.com/Foo.Bar/1.0.0'
        PowerShellModuleProjectUri  = 'https://github.com/Baz/Foo.Bar'
        PowerShellModuleVersion     = '1.0.0'
        PuppetModuleName            = 'foo_bar'
      }

      $Result = Get-ReadmeContent @Parameters

      It 'Has the puppet module name as the title' {
        $Result | Should -MatchExactly "# $($Parameters.PuppetModuleName)"
      }
      It 'Includes the link to the builder, the upstream module, and the module version in the first para' {
        $Result | Should -MatchExactly "\[Puppet DSC Builder\]\(.+\)"
        $Result | Should -MatchExactly "\[$($Parameters.PowerShellModuleName)\]\($($Parameters.PowerShellModuleGalleryUri)\)"
        $Result | Should -MatchExactly "v$([Regex]::Escape($Parameters.PowerShellModuleVersion))"
      }
      It 'Includes the module description as a quote' {
        $Result | Should -MatchExactly "> _$($Parameters.PowerShellModuleDescription)_"
      }
      It 'Links to the Resource API and pwshlib dependencies' {
        $Result | Should -MatchExactly "\[Puppet Resource API\]\(.+\)"
        $Result | Should -MatchExactly "\[puppetlabs/pwshlib\]\(.+\)"
      }
      It 'Links to the base provider on github' {
        $Result | Should -MatchExactly "\(https://github.com/.+/dsc_base_provider.rb\)"
      }
      It 'Links to further narrative documentation' {
        $Result | Should -MatchExactly '\[narrative documentation\]\(.+\)'
      }
      It 'Links to the issues page for the builder, the pwslib module, and the upstream module' {
        $Result | Should -MatchExactly "\[file an issue\]\(.+puppetlabs/PuppetDscBuilder/issues/new/choose\)"
        $Result | Should -MatchExactly "\[file an issue\]\(.+puppetlabs/ruby-pwsh/issues/new/choose\)"
        $Result | Should -MatchExactly "\[file an issue\]\($($Parameters.PowerShellModuleProjectUri)\)"
      }
    }
  }
}
